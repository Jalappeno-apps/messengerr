require "yaml"
require "fileutils"
require "securerandom"

module Messengerr
  # Encrypted YAML store for integration credentials (Rails-credentials-style).
  #
  # Threat model: the encrypted file protects credentials only when the master
  # key is kept separate from it. Set MESSENGERR_MASTER_KEY (hex, 64 chars) to
  # keep the key out of the filesystem entirely. Otherwise a master.key file
  # (mode 600, dir 700) is generated next to the credentials file — equivalent
  # in practice to a mode-600 plaintext file, protecting mainly against the
  # .enc file leaking on its own (backups, VCS, shared systems).
  class Credentials
    def initialize(credentials_path: Paths.credentials_file, key_path: Paths.master_key_file)
      @credentials_path = credentials_path
      @key_path = key_path
    end

    def read(integration_key)
      data.fetch("integrations", {}).fetch(integration_key.to_s, nil)
    end

    def write(integration_key, values)
      merged = data
      merged["integrations"] ||= {}
      merged["integrations"][integration_key.to_s] = values.transform_keys(&:to_s)
      persist(merged)
    end

    def configured?(integration_key)
      !read(integration_key).nil?
    end

    def keys
      data.fetch("integrations", {}).keys
    end

    def exists?
      File.exist?(@credentials_path)
    end

    def delete_file!
      FileUtils.rm_f(@credentials_path)
    end

    def purge!
      delete_file!
      FileUtils.rm_f(@key_path)
    end

    private

    def data
      return {} unless exists?

      YAML.safe_load(Crypto.decrypt(File.read(@credentials_path), master_key(read_only: true))) || {}
    rescue Psych::SyntaxError
      raise CredentialsError, "credentials file decrypted to invalid YAML — it may be corrupted"
    end

    def persist(hash)
      dir = File.dirname(@credentials_path)
      # mkdir_p creates missing directories 0700; directories that already
      # exist (e.g. a shared MESSENGERR_CONFIG_DIR) are never chmod-ed.
      FileUtils.mkdir_p(dir, mode: 0o700)
      write_secret(@credentials_path, Crypto.encrypt(YAML.dump(hash), master_key))
    rescue Errno::EACCES, Errno::EROFS
      raise CredentialsError,
            "cannot write #{@credentials_path} — check permissions on #{dir}"
    end

    def master_key(read_only: false)
      env_key = ENV["MESSENGERR_MASTER_KEY"]
      return env_master_key(env_key) if env_key

      if File.exist?(@key_path)
        hex = File.read(@key_path).strip
        unless hex.match?(/\A[0-9a-fA-F]{64}\z/)
          raise CredentialsError, "#{@key_path} is malformed — run `messengerr credentials delete --purge` to reset"
        end
        [ hex ].pack("H*")
      elsif read_only
        raise CredentialsError,
              "credentials exist but no master key is available — set MESSENGERR_MASTER_KEY " \
              "or run `messengerr credentials delete` to reset"
      else
        key = SecureRandom.random_bytes(32)
        write_secret(@key_path, key.unpack1("H*"))
        key
      end
    end

    # An explicitly set key must be valid: an empty or malformed value is a
    # misconfiguration, never a reason to fall back to a key file silently.
    def env_master_key(value)
      hex = value.strip
      unless hex.match?(/\A\h{64}\z/)
        raise CredentialsError,
              "MESSENGERR_MASTER_KEY must be 64 hex characters (32 bytes)" \
              "#{' — it is set but empty' if hex.empty?}; unset it to use the key file instead"
      end
      [ hex ].pack("H*")
    end

    # Create files 0600 from birth and write atomically (temp + rename) so a
    # crash never leaves a truncated credentials file.
    def write_secret(path, contents)
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir, mode: 0o700)

      tmp = File.join(dir, ".#{File.basename(path)}.tmp")
      File.open(tmp, File::WRONLY | File::CREAT | File::TRUNC, 0o600) { |f| f.write(contents) }
      File.rename(tmp, path)
    end
  end
end

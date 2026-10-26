require "yaml"
require "fileutils"
require "securerandom"

module Messengerr
  # Encrypted YAML store for service credentials (Rails-credentials-style).
  # The encrypted file and its master key live inside the installed gem
  # directory so both are removed when the gem is uninstalled.
  class Credentials
    def initialize(credentials_path: Paths.credentials_file, key_path: Paths.master_key_file)
      @credentials_path = credentials_path
      @key_path = key_path
    end

    def read(service_key)
      data.fetch("services", {}).fetch(service_key.to_s, nil)
    end

    def write(service_key, values)
      merged = data
      merged["services"] ||= {}
      merged["services"][service_key.to_s] = values.transform_keys(&:to_s)
      persist(merged)
    end

    def configured?(service_key)
      !read(service_key).nil?
    end

    def keys
      data.fetch("services", {}).keys
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
    end

    def persist(hash)
      FileUtils.mkdir_p(File.dirname(@credentials_path))
      write_secret(@credentials_path, Crypto.encrypt(YAML.dump(hash), master_key))
    rescue Errno::EACCES, Errno::EROFS
      raise CredentialsError,
            "cannot write #{@credentials_path} — the gem is installed in a read-only location"
    end

    def master_key(read_only: false)
      if File.exist?(@key_path)
        [File.read(@key_path).strip].pack("H*")
      elsif read_only
        raise CredentialsError,
              "credentials exist but #{@key_path} is gone — run `messengerr credentials delete` to reset"
      else
        key = SecureRandom.random_bytes(32)
        FileUtils.mkdir_p(File.dirname(@key_path))
        write_secret(@key_path, key.unpack1("H*"))
        key
      end
    end

    def write_secret(path, contents)
      File.write(path, contents)
      File.chmod(0o600, path)
    end
  end
end

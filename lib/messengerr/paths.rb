module Messengerr
  # Locations for gem-owned files. Credentials live inside the installed gem
  # directory so they are removed when the gem is uninstalled or upgraded.
  module Paths
    def self.gem_root
      File.expand_path("../..", __dir__)
    end

    def self.config_dir
      File.join(gem_root, "config")
    end

    def self.credentials_file
      File.join(config_dir, "credentials.yml.enc")
    end

    def self.master_key_file
      File.join(config_dir, "master.key")
    end
  end
end

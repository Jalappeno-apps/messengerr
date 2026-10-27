module Messengerr
  # Locations for messengerr-owned files. Credentials live in the user's
  # config directory (~/.config/messengerr by default, overridable with
  # MESSENGERR_CONFIG_DIR) so they survive gem upgrades.
  module Paths
    def self.config_dir
      override = ENV["MESSENGERR_CONFIG_DIR"].to_s.strip
      override.empty? ? File.join(Dir.home, ".config", "messengerr") : override
    end

    def self.credentials_file
      File.join(config_dir, "credentials.yml.enc")
    end

    def self.master_key_file
      File.join(config_dir, "master.key")
    end
  end
end

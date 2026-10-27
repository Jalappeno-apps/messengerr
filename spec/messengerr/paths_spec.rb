RSpec.describe Messengerr::Paths do
  it "defaults to ~/.config/messengerr" do
    with_env("MESSENGERR_CONFIG_DIR" => nil) do
      expect(described_class.config_dir).to eq(File.join(Dir.home, ".config", "messengerr"))
    end
  end

  it "honours MESSENGERR_CONFIG_DIR" do
    with_env("MESSENGERR_CONFIG_DIR" => "/somewhere/else") do
      expect(described_class.credentials_file).to eq("/somewhere/else/credentials.yml.enc")
      expect(described_class.master_key_file).to eq("/somewhere/else/master.key")
    end
  end

  it "ignores a blank MESSENGERR_CONFIG_DIR instead of writing to the filesystem root" do
    ["", "   "].each do |blank|
      with_env("MESSENGERR_CONFIG_DIR" => blank) do
        expect(described_class.config_dir).to eq(File.join(Dir.home, ".config", "messengerr"))
        expect(described_class.credentials_file).not_to start_with("/credentials")
      end
    end
  end
end

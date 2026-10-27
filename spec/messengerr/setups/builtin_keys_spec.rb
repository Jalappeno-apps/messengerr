RSpec.describe "built-in setups" do
  it "Postmark requires server_token and from" do
    expect(Messengerr::Setups::Postmark.required_keys).to eq([ :server_token, :from ])
    expect(Messengerr::Setups::Postmark.integration_class).to eq(Messengerr::Integrations::Postmark)
  end

  it "ClickSend requires username and api_key with optional from" do
    expect(Messengerr::Setups::ClickSend.required_keys).to eq([ :username, :api_key ])
    expect(Messengerr::Setups::ClickSend.optional_keys).to eq([ :from ])
    expect(Messengerr::Setups::ClickSend.integration_class).to eq(Messengerr::Integrations::ClickSend)
  end
end

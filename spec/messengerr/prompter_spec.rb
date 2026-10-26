RSpec.describe Messengerr::Prompter do
  def prompter_for(script)
    input = StringIO.new(script)
    output = StringIO.new
    [described_class.new(input:, output:), output]
  end

  it "asks and reads a line" do
    prompter, output = prompter_for("hello\n")
    expect(prompter.ask("Name?")).to eq("hello")
    expect(output.string).to include("Name?")
  end

  it "choose returns the selected option" do
    prompter, = prompter_for("2\n")
    expect(prompter.choose("Pick", %w[a b c])).to eq("b")
  end

  it "choose reprompts on invalid input" do
    prompter, output = prompter_for("9\nx\n1\n")
    expect(prompter.choose("Pick", %w[a b])).to eq("a")
    expect(output.string).to include("between 1 and 2")
  end

  it "confirm is true for y and false otherwise" do
    yes, = prompter_for("y\n")
    no, = prompter_for("n\n")
    expect(yes.confirm("OK?")).to be(true)
    expect(no.confirm("OK?")).to be(false)
  end

  it "secret reads a line without echo on non-tty input" do
    prompter, = prompter_for("s3cr3t\n")
    expect(prompter.secret("Token:")).to eq("s3cr3t")
  end

  it "say writes a line" do
    prompter, output = prompter_for("")
    prompter.say("hi")
    expect(output.string).to eq("hi\n")
  end
end

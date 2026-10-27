require "io/console"

module Messengerr
  # Injectable stdin/stdout interaction so CLI flows are scriptable and testable.
  class Prompter
    def initialize(input: $stdin, output: $stdout, interactive: nil)
      @input = input
      @output = output
      @interactive = interactive.nil? ? (@input.respond_to?(:tty?) && @input.tty?) : interactive
    end

    # Real sends require a human at a terminal; anything else (pipes, agent
    # shells) is non-interactive. Specs inject the value.
    def interactive? = @interactive

    def say(message)
      @output.puts(message)
    end

    def ask(question)
      @output.print("#{question} ")
      @output.flush
      read_line
    end

    def secret(question)
      @output.print("#{question} ")
      @output.flush
      if @input.respond_to?(:noecho) && @input.tty?
        value = @input.noecho(&:gets)&.chomp
        @output.puts
        value
      else
        read_line
      end
    end

    def choose(question, options)
      @output.puts(question)
      options.each_with_index { |o, i| @output.puts("  #{i + 1}) #{o}") }
      loop do
        answer = ask("Choose 1-#{options.length}:")
        index = Integer(answer, exception: false)
        return options[index - 1] if index&.between?(1, options.length)

        @output.puts("Please enter a number between 1 and #{options.length}.")
      end
    end

    def confirm(question)
      answer = ask("#{question} [y/n]")
      answer.to_s.strip.downcase.start_with?("y")
    end

    private

    def read_line
      line = @input.gets
      raise Error, "unexpected end of input" if line.nil?

      line.chomp
    end
  end
end

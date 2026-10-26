require "zeitwerk"
require_relative "messengerr/version"
require_relative "messengerr/errors"

module Messengerr
  class << self
    def loader
      @loader ||= Zeitwerk::Loader.for_gem.tap do |loader|
        loader.inflector.inflect("cli" => "CLI")
        loader.ignore("#{__dir__}/messengerr/version.rb", "#{__dir__}/messengerr/errors.rb")
        loader.setup
      end
    end
  end
end

Messengerr.loader

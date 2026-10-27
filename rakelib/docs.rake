require_relative "docs_integrations"

namespace :docs do
  desc "Regenerate docs/integrations.md from the integration registry"
  task :integrations do
    File.write(DocsIntegrations::PATH, DocsIntegrations.render)
    puts "Wrote #{DocsIntegrations::PATH}"
  end

  desc "Fail if docs/integrations.md is out of date (run `rake docs:integrations`)"
  task :check do
    current = File.exist?(DocsIntegrations::PATH) ? File.read(DocsIntegrations::PATH, encoding: "UTF-8") : ""
    abort "docs/integrations.md is out of date. Run `bundle exec rake docs:integrations` and commit the result." unless current == DocsIntegrations.render
    puts "docs/integrations.md is up to date"
  end
end

require "bundler/setup"
%w[activesupport actionview actionpack].each { $LOAD_PATH.unshift File.join(ENV["RAILS"], _1, "lib") }
require "action_view"; require "action_view/testing/resolvers"; require "maildown"; require "maildown/handlers/markdown"
module Rails; def self.version = ActionView.version.to_s; end
Maildown::Handlers::Markdown.instance_variable_set(:@erb_handler, nil)
ActionView::Template.register_template_handler(:md, Maildown::Handlers::Markdown)
view = ActionView::Base.with_empty_template_cache.with_view_paths(ActionView::FixtureResolver.new("mailer/welcome.html.md" => "# Hi <%= 1 + 1 %>"))
puts((view.render(template: "mailer/welcome").inspect rescue "#{$!.class}: #{$!.message[0, 80]}"))

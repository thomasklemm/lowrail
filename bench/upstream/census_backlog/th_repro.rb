# A minimal Markdown-style handler that, like maildown 3.3.1, gets the ERB handler with registered_template_handler(:erb)
require "bundler/setup"
%w[activesupport actionview actionpack].each { $LOAD_PATH.unshift File.join(ENV["RAILS"], _1, "lib") }
require "action_view"; require "action_view/testing/resolvers"
module ActionView
  module Template::Handlers
    class Markdown
      def self.call(template, source = template.source)
        "#{name}.render(begin;#{erb.call(template, source)};end)"
      end
      def self.render(s) = s.to_s.upcase.html_safe
      def self.erb = @erb ||= ActionView::Template.registered_template_handler(:erb)
    end
  end
end
ActionView::Template.register_template_handler(:md, ActionView::Template::Handlers::Markdown)
view = ActionView::Base.with_empty_template_cache.with_view_paths(ActionView::FixtureResolver.new("notes/show.html.md" => "hello <%= 1 + 1 %>"))
begin
  puts "render: #{view.render(template: "notes/show").inspect}"
rescue => e
  puts "render: #{e.class}: #{e.message[0, 90]}"
end
%i[template_handler_extensions].each { |m| r = (ActionView::Template.public_send(m) rescue $!.class); puts "#{m}: #{r.inspect}" }
puts "registered(nil): #{(ActionView::Template.registered_template_handler(nil) rescue $!.class).inspect}"
puts "registered(:nope): #{(ActionView::Template.registered_template_handler(:nope) rescue $!.class).inspect}"

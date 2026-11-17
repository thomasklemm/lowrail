# ruby -rbundler/setup fh2_amt_override.rb RAILS: an app override of TagHelper#content_tag that reads options with extract_options!
rails = ARGV.fetch(0)
%w[activesupport actionview actionpack activemodel].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support/all"
require "action_view"
module DataTestId
  def content_tag(name, *args, &block)
    options = args.extract_options!
    options[:data] = { test: name } if %w[textarea label].include?(name.to_s)
    super(name, *args, options, &block)
  end
end
ActionView::Helpers::TagHelper.prepend(DataTestId)
Post = Struct.new(:title, :body)
f = ActionView::Helpers::FormBuilder.new(:post, Post.new("t", "b"), ActionView::Base.empty, {})
puts f.text_area(:body), f.label(:title), f.label(:title, "Text"), ActionView::Base.empty.content_tag(:label, "plain")

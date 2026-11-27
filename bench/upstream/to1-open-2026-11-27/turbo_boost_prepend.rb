# turbo_boost-commands' TagBuilder patch shape (lib/turbo_boost/commands/patches/action_view_helpers_tag_helper_tag_builder_patch.rb):
# a prepend `tag_options(options, ...)` that rewrites options and calls super. Run per tree; outputs must match.
rails = ARGV[0]
%w[activesupport actionview actionpack activemodel].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"; require "active_support/core_ext"; require "action_view"
ActionView::Helpers::TagHelper::TagBuilder.prepend(Module.new do
  def tag_options(options, ...)
    options = options.merge("data-state" => "s")
    super
  end
end)
v = ActionView::Base.empty
p v.tag(:input, type: "text"), v.tag.input(type: "text"), v.tag.br(class: "c"), v.text_field_tag(:q), v.image_tag("/a.png"), v.content_tag(:p, "x", class: "c"), v.tag(:br)

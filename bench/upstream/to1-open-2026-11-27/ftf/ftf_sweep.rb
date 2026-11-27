# f.text_field(:title) with a title of LEN characters; Callgrind per call as ftf_ir.rb.  ruby ftf_sweep.rb RAILS LEN N
rails, len, n = ARGV[0], Integer(ARGV[1]), Integer(ARGV[2])
%w[activesupport actionview actionpack activemodel].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support/all"; require "active_model"; require "action_view"; require "action_controller"
class Post; include ActiveModel::Model; attr_accessor :title; end
f = ActionView::Helpers::FormBuilder.new(:post, Post.new(title: "t" * len), ActionView::Base.empty, {})
3000.times { f.text_field(:title) }
GC.start; GC.disable
[1].cycle(n) { f.text_field(:title) }

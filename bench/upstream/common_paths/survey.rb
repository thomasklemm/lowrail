require_relative "app"

v = view_context
post = Post.first
author = Author.first
time = Time.utc(2026, 1, 2, 3, 4, 5)
params = ActionController::Parameters.new(post: { title: "x", body: "y", author_id: "1" }, page: "2")

ops = {
  "link_to path" => -> { v.link_to("Home", "/home") },
  "link_to record" => -> { v.link_to("Post", post) },
  "post_path" => -> { v.post_path(post) },
  "post_comments_path" => -> { v.post_comments_path(post) },
  "url_for hash" => -> { v.url_for(controller: "posts", action: "index") },
  "tag.div class" => -> { v.tag.div("x", class: "a b") },
  "tag.div block" => -> { v.tag.div { "x" } },
  "content_tag" => -> { v.content_tag(:p, "x", class: "c") },
  "image_tag" => -> { v.image_tag("logo.png", alt: "L") },
  "button_to" => -> { v.button_to("Del", "/posts/1", method: :delete) },
  "form_with" => -> { v.form_with(model: post) { |f| f.text_field(:title) } },
  "time_tag" => -> { v.time_tag(time) },
  "dom_id" => -> { v.dom_id(post) },
  "number_with_delimiter" => -> { v.number_with_delimiter(1234567) },
  "truncate" => -> { v.truncate("hello world this is long", length: 10) },
  "pluralize" => -> { v.pluralize(2, "post") },
  "time_ago" => -> { v.time_ago_in_words(time) },
  "l time" => -> { v.l(time, format: :short) },
  "t missing" => -> { I18n.t("hello") },
  "simple_format" => -> { v.simple_format("a\n\nb") },
  "params.permit" => -> { params.require(:post).permit(:title, :body) },
  "params[:page]" => -> { params[:page] },
  "Post.find" => -> { Post.find(post.id) },
  "Post.where.first" => -> { Post.where(title: "Post 1").first },
  "Post.published.to_a" => -> { Post.published.to_a },
  "post.comments.to_a" => -> { Post.find(post.id).comments.to_a },
  "Post.exists?" => -> { Post.exists?(post.id) },
  "Post.count" => -> { Post.count },
  "pluck" => -> { Post.pluck(:id) },
  "post.author" => -> { Comment.first.post },
  "update" => -> { post.update!(title: "Post 0") },
  "as_json" => -> { post.as_json },
  "to_json" => -> { post.to_json },
  "cache_key_with_version" => -> { post.cache_key_with_version },
  "parameterize" => -> { "Hello World".parameterize },
  "Time.current" => -> { Time.current },
  "to_fs" => -> { time.to_fs(:db) },
}

only = ARGV.first && Regexp.new(ARGV.first)
ops.each do |name, op|
  next if only && name !~ only
  printf "%-26s %7.1f\n", name, allocs(&op)
  if only
    sites(&op).each { |k, n| printf "   %6.2f %s\n", n, k }
  end
end

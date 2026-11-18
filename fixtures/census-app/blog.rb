# The Blog's workloads, as its developer would write them in lowrail/workloads.rb.
# Evaluated inside the booted app; plain Ruby looks records up.
article = Article.order(:id).first!
target = Article.order(:id).last!

setup do
  # Writes must not accumulate from run to run, or the A/A pair drifts.
  Comment.where(commenter: "Census").delete_all
  Article.where(title: ["Census title A", "Census title B"]).where.not(id: article.id).delete_all
end

csrf_from new_article_path

get articles_path, name: "GET articles"
get article_path(article), name: "GET article"
get edit_article_path(article), name: "GET article edit"
get articles_path(format: :json), as: :json, name: "GET articles.json"
get article_path(article, format: :json), as: :json, name: "GET article.json"

# Flip between two titles, so the record ends each run as it started.
titles = ["Census title A", "Census title B"].map { { params: { article: { title: _1, body: article.body } } } }
patch article_path(article), name: "PATCH article (redirect)", expect: 303, jobs: true, alternate: titles
post articles_path, name: "POST article invalid (422)", params: { article: { title: "", body: "short" } }, expect: 422
post article_comments_path(target), name: "POST comment (redirect)",
  params: { comment: { commenter: "Census", body: "A census comment" } }, expect: 302
patch article_path(article, format: :json), as: :json, name: "PATCH article.json", alternate: titles

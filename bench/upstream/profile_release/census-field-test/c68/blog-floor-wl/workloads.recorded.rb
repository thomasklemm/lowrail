# Workloads for lowrail-profile --workloads (README-profile.md).
# Recorded by `lowrail-profile --record -- bin/rails test -v`: the 8 most frequent
# request shapes of 10 requests, most frequent first. Records are each model's first row.
# Only GETs that replay as recorded are enabled. Writes keep the params one test sent and are commented out until
# you make them repeatable (setup, alternate:); so is any request whose params were filtered or shortened.
# Recorded from real requests: values the app's filter_parameters hides are [FILTERED],
# but check the file for other secrets before you commit it.

article = Article.first!
# comment = Comment.first!

# 2 requests (a write: make it repeatable, then uncomment)
# post articles_path, name: "POST /articles", params: {"article" => {"body" => "A sufficiently long body for validation.", "title" => "New Title"}}

# 2 requests (a write: make it repeatable, then uncomment)
# post article_comments_path(article), name: "POST /articles/:article_id/comments", params: {"comment" => {"commenter" => "Test", "body" => "A test comment."}}

# 1 request
get articles_path, name: "GET /articles (text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5)", headers: { "Accept" => "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5" }

# 1 request
get article_path(article), name: "GET /articles/:id (text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5)", headers: { "Accept" => "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5" }

# 1 request
get edit_article_path(article), name: "GET /articles/:id/edit (text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5)", headers: { "Accept" => "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5" }

# 1 request
get new_article_path, name: "GET /articles/new (text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5)", headers: { "Accept" => "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5" }

# 1 request (a write: make it repeatable, then uncomment)
# delete article_comment_path(article, comment), name: "DELETE /articles/:article_id/comments/:id"

# 1 request (a write: make it repeatable, then uncomment)
# delete article_path(article), name: "DELETE /articles/:id"

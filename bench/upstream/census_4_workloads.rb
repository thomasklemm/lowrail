# frozen_string_literal: true

# Census 4 workloads per app. Each returns RailsMainCensus4::Op values whose
# call performs one ordinary operation and raises unless it succeeded.
module Census4Workloads
  module_function

  def op(c, name, kind, &block) = c::Op.new(name, kind, block)

  def html(c, client, name, path) = op(c, name, :html) { client.get(path) }

  def json_headers(token = nil)
    h = { "HTTP_ACCEPT" => "application/json", "CONTENT_TYPE" => "application/json" }
    h["HTTP_X_CSRF_TOKEN"] = token if token
    h
  end

  TURBO = { "HTTP_ACCEPT" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  def blog(c)
    client = c::Client.new
    article = Article.order(:id).first!
    target = Article.order(:id).last!
    Comment.where(commenter: "Census").delete_all
    Article.where(title: ["Census title A", "Census title B"]).where.not(id: article.id).delete_all
    token = client.csrf("/articles/new")
    n = [0]
    patch = -> { { article: { title: c.flip(n, "Census title A", "Census title B"), body: article.body } } }
    ops = [
      html(c, client, "GET articles", "/articles"),
      html(c, client, "GET article", "/articles/#{article.id}"),
      html(c, client, "GET article edit", "/articles/#{article.id}/edit"),
      op(c, "GET articles.json", :json) { client.get("/articles.json", headers: json_headers) },
      op(c, "GET article.json", :json) { client.get("/articles/#{article.id}.json", headers: json_headers) },
      op(c, "PATCH article (redirect)", :form) {
        client.patch("/articles/#{article.id}", params: patch.call.merge(authenticity_token: token), expect: 303)
      },
      op(c, "POST article invalid (422)", :form) {
        client.post("/articles", params: { article: { title: "", body: "short" }, authenticity_token: token }, expect: 422)
      },
      op(c, "POST comment (redirect)", :form) {
        client.post("/articles/#{target.id}/comments",
          params: { comment: { commenter: "Census", body: "A census comment" }, authenticity_token: token }, expect: 302)
      },
      op(c, "PATCH article.json", :json) {
        client.patch("/articles/#{article.id}.json", body: JSON.generate(patch.call), headers: json_headers(token))
      },
    ]
    jobs = c.jobs_from { client.patch("/articles/#{article.id}", params: patch.call.merge(authenticity_token: token), expect: 303) }
    add_jobs(c, ops, jobs)
  end

  def add_jobs(c, ops, jobs)
    jobs.uniq { _1["job_class"] }.each { |job| ops << c.job_op("perform #{job["job_class"]}", job) }
    ops
  end

  def campfire(c)
    user = User.find_by!(email_address: "david@37signals.com")
    login = user.sessions.start!(user_agent: c::UA, ip_address: "127.0.0.1")
    client = c::Client.new
    client.cookie(*c.signed_cookie(:session_token, login.token))
    room = Room.find_by!(name: "All Talk")
    target = Room.find_by!(name: "Designers")
    target.messages.where(creator: user).delete_all
    token = client.csrf("/rooms/#{room.id}", required: false)
    message = target.messages.create!(creator: user, body: "Census message")
    bot = User.find_by!(name: "Bender Bot")
    bot_room = bot.rooms.first!
    bot_room.messages.where(creator: bot).delete_all
    bot_client = c::Client.new
    n = [0]
    ops = [
      html(c, client, "GET room", "/rooms/#{room.id}"),
      html(c, client, "GET sidebar", "/users/me/sidebar"),
      html(c, client, "GET search", "/searches?q=coffee"),
      op(c, "POST message (turbo_stream)", :turbo) {
        client.post("/rooms/#{target.id}/messages", params: { message: { body: "Census hello" }, authenticity_token: token },
          headers: TURBO)
      },
      op(c, "PATCH message (redirect)", :form) {
        client.patch("/rooms/#{target.id}/messages/#{message.id}",
          params: { message: { body: c.flip(n, "Census edit A", "Census edit B") }, authenticity_token: token }, expect: 302)
      },
      op(c, "GET bot messages.json", :json) {
        bot_client.get("/rooms/#{bot_room.id}/#{bot.bot_key}/messages", headers: json_headers)
      },
      op(c, "POST bot message (201)", :json) {
        bot_client.post("/rooms/#{bot_room.id}/#{bot.bot_key}/messages", body: "Census bot hello",
          headers: { "CONTENT_TYPE" => "text/plain" }, expect: 201)
      },
    ]
    jobs = c.jobs_from {
      client.post("/rooms/#{target.id}/messages", params: { message: { body: "Census hello" }, authenticity_token: token },
        headers: TURBO)
    }
    add_jobs(c, ops, jobs)
  end

  def writebook(c)
    user = User.find_by!(email_address: "david@example.com")
    login = user.sessions.start!(user_agent: c::UA, ip_address: "127.0.0.1")
    client = c::Client.new
    client.cookie(*c.signed_cookie(:session_token, login.token))
    book = Book.find_by!(slug: "handbook")
    leaf = book.leaves.find_by!(title: "Welcome to The Handbook!")
    book.leaves.where(title: ["Census page", "Census edited page"]).find_each { |l| l.leafable.destroy; l.destroy }
    page = book.press(Page.new(body: "Census body"), title: "Census edited page")
    token = client.csrf("/")
    n = [0]
    update = -> {
      client.patch("/books/#{book.id}/pages/#{page.id}", headers: TURBO,
        params: { page: { body: c.flip(n, "Census body A", "Census body B") }, leaf: { title: "Census edited page" },
          authenticity_token: token })
    }
    ops = [
      html(c, client, "GET books", "/"),
      html(c, client, "GET book", "/#{book.id}/#{book.slug}"),
      html(c, client, "GET leaf", "/#{book.id}/#{book.slug}/#{leaf.id}/#{leaf.slug}"),
      op(c, "GET leaf.md", :html) { client.get("/#{book.id}/#{book.slug}/#{leaf.id}/#{leaf.slug}.md", headers: { "HTTP_ACCEPT" => "text/markdown" }) },
      op(c, "PATCH page (turbo_stream)", :turbo, &update),
      op(c, "POST search", :form) {
        client.post("/books/#{book.id}/search", params: { search: "handbook", authenticity_token: token })
      },
      op(c, "POST page (turbo_stream)", :turbo) {
        client.post("/books/#{book.id}/pages", headers: TURBO,
          params: { page: { body: "Census new page" }, leaf: { title: "Census page" }, authenticity_token: token })
      },
    ]
    add_jobs(c, ops, c.jobs_from(&update))
  end

  def fizzy(c)
    identity = Identity.find_by!(email_address: "kevin@37signals.com")
    login = identity.sessions.create!
    client = c::Client.new
    client.cookie(*c.signed_cookie(:session_token, login.signed_id))
    user = identity.users.find_by!(name: "Kevin")
    account = user.account
    prefix = "/#{account.external_account_id}"
    board = account.boards.find_by!(name: "Writebook")
    shown, target = Current.set(account: account) { board.cards.order(:number).first(2) }
    Current.set(account: account, user: user) do
      target.comments.where(creator: user).find_each(&:destroy)
    end
    comment = Current.set(account: account, user: user) { target.comments.create!(body: "Census comment") }
    magic_link = identity.magic_links.create!
    n = [0]
    comment_path = "#{prefix}/cards/#{target.number}/comments"
    create = -> { client.post(comment_path, headers: TURBO, params: { comment: { body: "Census hello" } }) }
    ops = [
      html(c, client, "GET board", "#{prefix}/boards/#{board.id}"),
      html(c, client, "GET cards", "#{prefix}/cards"),
      html(c, client, "GET notifications", "#{prefix}/notifications"),
      html(c, client, "GET card", "#{prefix}/cards/#{shown.number}"),
      op(c, "GET cards.json", :json) { client.get("#{prefix}/cards.json", headers: json_headers) },
      op(c, "GET card.json", :json) { client.get("#{prefix}/cards/#{shown.number}.json", headers: json_headers) },
      op(c, "POST comment (turbo_stream)", :turbo, &create),
      op(c, "PATCH comment (turbo_stream)", :turbo) {
        client.patch("#{comment_path}/#{comment.id}", headers: TURBO,
          params: { comment: { body: c.flip(n, "Census edit A", "Census edit B") } })
      },
      op(c, "POST comment.json (201)", :json) {
        client.post(comment_path, body: JSON.generate(comment: { body: "Census json" }), headers: json_headers, expect: 201)
      },
      c.mail_op("deliver MagicLinkMailer") { MagicLinkMailer.sign_in_instructions(magic_link) },
    ]
    add_jobs(c, ops, c.jobs_from(&create))
  end
  singleton_class.alias_method :fizzy_mysql, :fizzy

  # Devise remember-me cookie, as a returning browser would send it.
  def devise_client(c, user, scope = :user)
    user.remember_me! if user.respond_to?(:remember_me!)
    client = c::Client.new
    client.cookie(*c.signed_cookie("remember_#{scope}_token", user.class.serialize_into_cookie(user)))
    client
  end

  def codetriage(c)
    repo = Repo.find_by!(full_name: "schneems/get_process_mem")
    anon = c::Client.new
    user = User.find_by!(github: "schneems")
    client = devise_client(c, user)
    sub = user.repo_subscriptions.first!
    token = client.csrf("/users/#{user.id}/edit")
    n = [0]
    ops = [
      html(c, anon, "GET home", "/"),
      html(c, anon, "GET repo", "/#{repo.full_name}"),
      html(c, anon, "GET subscribers", "/rails/rails/subscribers"),
      html(c, client, "GET user edit (signed in)", "/users/#{user.id}/edit"),
      op(c, "GET repo info.json", :json) { anon.get("/#{repo.full_name}/info.json", headers: json_headers) },
      op(c, "PATCH repo subscription (redirect)", :form) {
        client.patch("/repo_subscriptions/#{sub.id}", expect: 302,
          params: { repo_subscription: { email_limit: c.flip(n, "3", "4") }, authenticity_token: token })
      },
      c.job_op("perform SendSingleTriageEmailJob", SendSingleTriageEmailJob.new(sub.id).serialize),
      # No mailer workload (recorded): maildown 3.3.1 calls ActionView::Template.registered_template_handler,
      # which Rails main no longer defines, so CodeTriage's Markdown mail cannot render on main.
    ]
    ops
  end

  # Inertia XHR headers: the asset version from the first HTML page.
  def inertia_headers(client, path, token)
    html = CGI.unescapeHTML(client.get(path).body)
    version = html[/"version":("[^"]*"|null)/, 1] or raise "no Inertia version on #{path}"
    h = { "HTTP_X_INERTIA" => "true", "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
      "HTTP_ACCEPT" => "text/html, application/xhtml+xml", "HTTP_X_CSRF_TOKEN" => token }
    h["HTTP_X_INERTIA_VERSION"] = JSON.parse(version) if version != "null"
    h
  end

  def pingcrm(c)
    user = User.find_by!(email: "johndoe@example.com")
    client = devise_client(c, user)
    token = client.csrf("/")
    xhr = inertia_headers(client, "/contacts", token)
    xhr_json = xhr.merge("CONTENT_TYPE" => "application/json")
    contact = user.account.contacts.order(:id).first!
    n = [0]
    [
      html(c, client, "GET dashboard", "/"),
      html(c, client, "GET contacts", "/contacts"),
      html(c, client, "GET organizations", "/organizations"),
      html(c, client, "GET contact edit", "/contacts/#{contact.id}/edit"),
      op(c, "GET contacts (Inertia JSON)", :json) { client.get("/contacts", headers: xhr) },
      op(c, "GET organizations (Inertia JSON)", :json) { client.get("/organizations", headers: xhr) },
      op(c, "PUT contact (Inertia redirect)", :form) {
        client.put("/contacts/#{contact.id}", headers: xhr_json, expect: [302, 303],
          body: JSON.generate(contact: { first_name: c.flip(n, "Census", "Censa"), last_name: contact.last_name }))
      },
      op(c, "POST contact invalid (Inertia errors)", :form) {
        client.post("/contacts", headers: xhr_json, expect: [302, 303],
          body: JSON.generate(contact: { first_name: "", last_name: "" }))
      },
    ]
  end

  # Inertia + Action Policy app on SQLite; its seeds create only admins, so the
  # workload adds one speaker with a profile and a submitted proposal.
  def redprints_cfp(c)
    user = User.find_or_create_by!(email: "census-speaker@example.com") { _1.name = "Census Speaker" }
    user.regenerate_auth_token if user.auth_token.nil?
    profile = user.speaker_profile || user.create_speaker_profile!(name: "Census Speaker", email: user.email, bio: "Bio")
    cfp = CFP.primary
    proposal = user.proposals.first || user.proposals.create!(title: "Census talk", abstract: "Abstract", details: "Details",
      pitch: "Pitch", track: "general", status: "submitted", submitted_at: Time.current, cfp_id: cfp.id)
    client = c::Client.new
    client.cookie(*c.signed_cookie(:session_token, user.auth_token))
    token = client.csrf("/proposals")
    xhr = inertia_headers(client, "/proposals", token).merge("CONTENT_TYPE" => "application/json")
    n = [0]
    fields = -> {
      { title: c.flip(n, "Census talk A", "Census talk B"), abstract: "Abstract", details: "Details", pitch: "Pitch",
        track: "general", speaker_name: profile.name, speaker_email: profile.email, speaker_bio: "Bio" }
    }
    [
      html(c, client, "GET home", "/"),
      html(c, client, "GET proposals", "/proposals"),
      html(c, client, "GET proposal", "/proposals/#{proposal.external_id}"),
      html(c, client, "GET proposal edit", "/proposals/#{proposal.external_id}/edit"),
      op(c, "GET proposals (Inertia JSON)", :json) { client.get("/proposals", headers: xhr) },
      op(c, "PATCH proposal (Inertia redirect)", :form) {
        client.patch("/proposals/#{proposal.external_id}", headers: xhr, expect: [302, 303],
          body: JSON.generate(proposal: fields.call))
      },
      op(c, "POST proposal invalid (Inertia errors)", :form) {
        client.post("/proposals", headers: xhr, expect: [302, 303],
          body: JSON.generate(proposal: { title: "", cfp_id: cfp.id }))
      },
      c.mail_op("deliver ProposalMailer#proposal_submitted") {
        ProposalMailer.with(proposal: proposal, speaker: profile).proposal_submitted
      },
    ]
  end

  # Inertia React starter kit on SQLite (Rails authentication generator style).
  def react_starter_kit(c)
    user = User.find_or_create_by!(email: "census@example.com") do |u|
      u.name = "Census"
      u.password = "census-password-123"
      u.verified = true
    end
    user.sessions.delete_all
    session = user.sessions.create!
    client = c::Client.new
    client.cookie(*c.signed_cookie(:session_token, session.id))
    token = client.csrf("/dashboard")
    xhr = inertia_headers(client, "/dashboard", token).merge("CONTENT_TYPE" => "application/json")
    n = [0]
    [
      html(c, client, "GET home", "/"),
      html(c, client, "GET dashboard", "/dashboard"),
      html(c, client, "GET settings profile", "/settings/profile"),
      html(c, client, "GET settings sessions", "/settings/sessions"),
      op(c, "GET dashboard (Inertia JSON)", :json) { client.get("/dashboard", headers: xhr) },
      op(c, "PATCH profile (Inertia redirect)", :form) {
        client.patch("/settings/profile", headers: xhr, expect: [302, 303],
          body: JSON.generate(name: c.flip(n, "Census A", "Census B")))
      },
      op(c, "PATCH profile invalid (Inertia errors)", :form) {
        client.patch("/settings/profile", headers: xhr, expect: [302, 303], body: JSON.generate(name: ""))
      },
      c.mail_op("deliver UserMailer#email_verification") { UserMailer.with(user: user).email_verification },
    ]
  end

  # Lobsters on SQLite with its own fake_data generator (seeded); signed in
  # through the real POST /login so logged-out page caching is not measured.
  def lobsters(c)
    user = User.active.where(is_moderator: false).order(:id).first!
    Comment.where("comment LIKE 'Census comment%'").find_each { |cm| Vote.where(comment_id: cm.id).delete_all; cm.delete }
    user.update!(password: "census-password", password_confirmation: "census-password")
    client = c::Client.new
    token = client.csrf("/login")
    client.post("/login", params: { email: user.email, password: "census-password", authenticity_token: token },
      expect: 302)
    token = client.csrf("/")
    stories = Story.where(is_deleted: false, merged_story_id: nil).where.not(user_id: user.id).order(:id)
    shown, target, voted = stories.first(3)
    tag = shown.tags.first!
    story_path = URI(client.get("/s/#{shown.short_id}", expect: 302).headers["location"]).path
    xhr = { "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest", "HTTP_X_CSRF_TOKEN" => token }
    n = [0]
    seq = [0]
    create = -> {
      client.post("/comments", headers: xhr,
        params: { story_id: target.short_id, comment: "Census comment #{seq[0] += 1} #{Process.pid}" })
    }
    ops = [
      html(c, client, "GET home", "/"),
      html(c, client, "GET active", "/active"),
      html(c, client, "GET story", story_path),
      html(c, client, "GET tag", "/t/#{tag.tag}"),
      op(c, "GET hottest.json", :json) { client.get("/hottest.json", headers: json_headers) },
      op(c, "GET story.json", :json) { client.get("/s/#{shown.short_id}.json", headers: json_headers) },
      op(c, "POST story vote toggle", :form) {
        client.post("/stories/#{voted.short_id}/#{c.flip(n, "upvote", "unvote")}", headers: xhr)
      },
      op(c, "POST comment preview", :form) {
        client.post("/comments", headers: xhr,
          params: { story_id: target.short_id, comment: "Census preview", preview: "1" })
      },
      op(c, "POST comment (XHR)", :form, &create),
    ]
    jobs = c.jobs_from(&create)
    reply = Comment.where(story_id: target.id).order(:id).last!
    ops << c.mail_op("deliver EmailReplyMailer#reply") { EmailReplyMailer.reply(reply, target.user) }
    add_jobs(c, ops, jobs.reject { _1["job_class"] == "CachePageJob" })
  end
end

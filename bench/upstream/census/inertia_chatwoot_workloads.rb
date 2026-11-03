# frozen_string_literal: true

# Workloads for the Chatwoot and Inertia census apps
# (docs/upstream/inertia-chatwoot-census.md). Same contract as
# census_4_workloads.rb: each op performs one ordinary operation and raises
# unless it succeeded; rows a write op adds are removed at setup.
module Census4Workloads
  module_function

  # Chatwoot (customer support inbox): the Vue dashboard's HTML shell and the
  # JSON API it calls, authenticated with devise_token_auth headers as the
  # dashboard sends them; the website widget for a returning visitor; an agent
  # reply and the jobs it enqueues.
  def chatwoot(c)
    account = Account.find_by!(name: "Census Inc")
    admin = User.find_by!(email: "census-admin@census.test")
    conversation = account.conversations.joins(:inbox).where(inboxes: { channel_type: "Channel::WebWidget" }).order(:id).first!
    conversation.messages.where("content LIKE 'Census reply%'").delete_all
    conversation.update_columns(status: Conversation.statuses[:open])
    # devise_token_auth keeps one token per client (up to 25) in users.tokens
    # and parses them on every request; start each run from none.
    admin.update_columns(tokens: {})
    api = json_headers.merge(admin.create_new_auth_token.to_h { |k, v| ["HTTP_#{k.upcase.tr("-", "_")}", v] })
    widget = conversation.inbox.channel
    visitor = ::Widget::TokenService.new(payload: { source_id: conversation.contact_inbox.source_id,
      inbox_id: conversation.inbox_id }).generate_token
    client = c::Client.new
    prefix = "/api/v1/accounts/#{account.id}"
    path = "#{prefix}/conversations/#{conversation.display_id}"
    n = [0]
    seq = [0]
    create = -> {
      client.post("#{path}/messages", headers: api,
        body: JSON.generate(content: "Census reply #{seq[0] += 1} #{Process.pid}", message_type: "outgoing", private: false))
    }
    ops = [
      html(c, client, "GET dashboard conversation", "/app/accounts/#{account.id}/conversations/#{conversation.display_id}"),
      html(c, client, "GET widget", "/widget?website_token=#{widget.website_token}&cw_conversation=#{visitor}"),
      op(c, "GET conversations", :json) { client.get("#{prefix}/conversations?status=open&assignee_type=all&page=1", headers: api) },
      op(c, "GET conversations meta", :json) { client.get("#{prefix}/conversations/meta?status=open", headers: api) },
      op(c, "GET conversation", :json) { client.get(path, headers: api) },
      op(c, "GET messages", :json) { client.get("#{path}/messages", headers: api) },
      op(c, "GET inboxes", :json) { client.get("#{prefix}/inboxes", headers: api) },
      op(c, "GET contacts", :json) { client.get("#{prefix}/contacts?page=1&sort=-last_activity_at", headers: api) },
      op(c, "GET profile", :json) { client.get("/api/v1/profile", headers: api) },
      op(c, "POST toggle_status", :json) {
        client.post("#{path}/toggle_status", headers: api, body: JSON.generate(status: c.flip(n, "pending", "open")))
      },
      op(c, "POST message", :json, &create),
    ]
    add_jobs(c, ops, c.jobs_from(&create))
  end

  # The token Inertia's client sends: the XSRF-TOKEN cookie inertia-rails sets.
  def xsrf_cookie(response)
    value = Array(response.headers["set-cookie"]).join("\n")[/XSRF-TOKEN=([^;\n]+)/, 1] or raise "no XSRF-TOKEN cookie"
    CGI.unescape(value)
  end

  # A partial reload or deferred-prop fetch, as Inertia's client sends it.
  def inertia_partial(xhr, component, props) =
    xhr.merge("HTTP_X_INERTIA_PARTIAL_COMPONENT" => component, "HTTP_X_INERTIA_PARTIAL_DATA" => props)

  # Flow (Aixle; agent workflows on a project board). Signed in through the
  # password form. Three controller levels share props (mostly
  # InertiaRails.always), every page's props are camelized by a
  # prop_transformer, and the board defers its activity feed.
  def flow(c)
    project = Project.find_by!(slug: "demo-alpha")
    board = project.board
    task = board.board_tasks.find_by!(title: ["Set up project workflows", "Set up project workflows (census)"])
    task.update_columns(title: "Set up project workflows")
    Project.where(name: "Census project").delete_all
    client = c::Client.new
    token = xsrf_cookie(client.get("/login"))
    client.post("/login", params: { user: { email: "john@example.com", password: ENV.fetch("ADMIN_PASSWORD") } },
      headers: { "HTTP_X_CSRF_TOKEN" => token }, expect: [302, 303])
    board_path = "/company/projects/#{project.id}/board"
    token = xsrf_cookie(client.get(board_path))
    xhr = inertia_headers(client, board_path, token)
    api = json_headers(token)
    n = [0]
    [
      html(c, client, "GET projects", "/company/projects"),
      html(c, client, "GET board", board_path),
      html(c, client, "GET sessions", "/company/projects/#{project.id}/sessions"),
      op(c, "GET board (Inertia XHR)", :json) { client.get(board_path, headers: xhr) },
      op(c, "GET board tasks (partial reload)", :json) {
        client.get(board_path, headers: inertia_partial(xhr, "Projects/Board/BoardPage", "tasks,columns"))
      },
      op(c, "GET board activities (deferred)", :json) {
        client.get(board_path, headers: inertia_partial(xhr, "Projects/Board/BoardPage", "recentActivities"))
      },
      op(c, "GET projects (Inertia XHR)", :json) { client.get("/company/projects", headers: xhr) },
      op(c, "GET api tasks", :json) { client.get("/api/v1/projects/#{project.id}/tasks?board_column_id=#{task.board_column_id}", headers: api) },
      op(c, "PATCH api task", :json) {
        client.patch("/api/v1/projects/#{project.id}/tasks/#{task.id}", headers: api,
          body: JSON.generate(board_task: { title: c.flip(n, "Set up project workflows", "Set up project workflows (census)") }))
      },
      op(c, "POST project invalid (Inertia errors)", :form) {
        client.post("/company/projects", headers: xhr.merge("CONTENT_TYPE" => "application/json"), expect: [302, 303],
          body: JSON.generate(project: { name: "" }))
      },
    ]
  end

  # Hackatime (coding-time tracker for Hack Club; Svelte). Signed in through a
  # sign-in link. The dashboard, projects and leaderboard defer their stats;
  # editor plugins push heartbeats and poll the status bar through the
  # WakaTime-compatible API.
  def hackatime(c)
    user = User.find_by!(slack_uid: "TEST123456")
    user.update_columns(display_name_override: nil)
    key = user.api_keys.order(:id).first!.token
    user.heartbeats.where("entity LIKE 'census/op/%'").delete_all
    client = c::Client.new
    link = user.sign_in_tokens.create!(token: SecureRandom.hex(16), expires_at: 1.hour.from_now, auth_type: :email)
    client.get("/auth/token/#{link.token}", expect: [302, 303])
    token = xsrf_cookie(client.get("/"))
    xhr = inertia_headers(client, "/", token)
    form = xhr.merge("CONTENT_TYPE" => "application/json")
    wakatime = bearer(key)
    n = [0]
    seq = [0]
    beat = -> {
      client.post("/api/hackatime/v1/users/current/heartbeats", headers: wakatime, expect: [201, 202], body: JSON.generate(
        entity: "census/op/file_#{seq[0] += 1}.rb", type: "file", category: "coding", time: Time.current.to_f, project: "census",
        language: "Ruby", is_write: true, lineno: 10, cursorpos: 4, lines: 120, editor: "vscode", operating_system: "linux"))
    }
    ops = [
      html(c, client, "GET dashboard", "/"),
      html(c, client, "GET projects", "/my/projects"),
      html(c, client, "GET leaderboards", "/leaderboards"),
      html(c, client, "GET settings profile", "/my/settings/profile"),
      op(c, "GET dashboard (Inertia XHR)", :json) { client.get("/", headers: xhr) },
      op(c, "GET dashboard stats (deferred)", :json) {
        client.get("/", headers: inertia_partial(xhr, "Home/SignedIn", "dashboard_stats"))
      },
      op(c, "GET leaderboard entries (deferred)", :json) {
        client.get("/leaderboards", headers: inertia_partial(xhr, "Leaderboards/Index", "entries"))
      },
      op(c, "PATCH display name (Inertia redirect)", :form) {
        client.patch("/my/settings/profile/display_name", headers: form, expect: [302, 303],
          body: JSON.generate(user: { display_name_override: c.flip(n, "Census A", "Census B") }))
      },
      op(c, "PATCH username invalid (Inertia 422)", :form) {
        client.patch("/my/settings/profile/username", headers: form, expect: 422, body: JSON.generate(user: { username: "x" * 40 }))
      },
      op(c, "GET statusbar today", :json) { client.get("/api/hackatime/v1/users/current/statusbar/today", headers: wakatime) },
      op(c, "POST heartbeat", :json, &beat),
    ]
    add_jobs(c, ops, c.jobs_from(&beat))
  end

  # Thinkroom (collaborative documents with AI provenance; React, SQLite).
  # Signed in through the password form. The index lists owned, pinned and
  # recent documents as lambda props with an optional archived list; the
  # document page carries comments, suggestions and activity.
  def thinkroom(c)
    # Rails' rate_limit counts every census write and login in Rails.cache (a
    # file store shared by all runs); keep the counting path but report a count
    # of 1 so repeated runs never trip the app's per-IP limits.
    WriteRateLimited::STORE.singleton_class.prepend(Module.new do
      def increment(name, amount = 1, **options)
        count = super
        name.to_s.start_with?("rate-limit:") && count ? 1 : count
      end
    end)
    doc = Document.find_by!(slug: "demo")
    doc.comments.where("body LIKE 'Census op%'").delete_all
    client = c::Client.new
    token = xsrf_cookie(client.get("/login"))
    client.post("/login", params: { email: "census@census.test", password: "census-password-123" },
      headers: { "HTTP_X_CSRF_TOKEN" => token }, expect: [302, 303])
    path = "/d/#{doc.slug}"
    token = xsrf_cookie(client.get("/"))
    xhr = inertia_headers(client, "/", token)
    form = xhr.merge("CONTENT_TYPE" => "application/json")
    seq = [0]
    comment = -> {
      client.post("#{path}/comments", headers: form, expect: [302, 303],
        body: JSON.generate(author_name: "Census Writer", body: "Census op comment #{seq[0] += 1}", anchor_text: "provenance"))
    }
    ops = [
      html(c, client, "GET documents", "/"),
      html(c, client, "GET document", path),
      op(c, "GET documents (Inertia XHR)", :json) { client.get("/", headers: xhr) },
      op(c, "GET archived (optional, partial reload)", :json) {
        client.get("/", headers: inertia_partial(xhr, "documents/index", "archived"))
      },
      op(c, "GET document (Inertia XHR)", :json) { client.get(path, headers: xhr) },
      op(c, "GET comments (partial reload)", :json) {
        client.get(path, headers: inertia_partial(xhr, "documents/show", "comments,suggestions,activities"))
      },
      op(c, "POST comment (Inertia redirect)", :form, &comment),
      op(c, "POST comment invalid (Inertia errors)", :form) {
        client.post("#{path}/comments", headers: form, expect: [302, 303], body: JSON.generate(author_name: "Census", body: ""))
      },
      op(c, "GET api doc", :json) { client.get("/api/docs/#{doc.slug}", headers: json_headers) },
    ]
    add_jobs(c, ops, c.jobs_from(&comment))
  end
end

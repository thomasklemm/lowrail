# frozen_string_literal: true

# Workloads for the PostgreSQL census apps (docs/upstream/pg-census.md). Same
# contract as census_4_workloads.rb: each op performs one ordinary operation
# and raises unless it succeeded; rows a write op adds are removed at setup.
module Census4Workloads
  module_function

  def bearer(token, extra = {}) = json_headers.merge("HTTP_AUTHORIZATION" => "Bearer #{token}").merge(extra)

  def add_sidekiq_jobs(c, ops, jobs)
    jobs.uniq { _1["class"] }.each { |job| ops << c.sidekiq_job_op("perform #{job["class"]}", job) }
    ops
  end

  # Docuseal (e-signature): Devise remember-me session for the dashboard pages,
  # the X-Auth-Token REST API, the public signing form and Sidekiq jobs.
  def docuseal(c)
    user = User.find_by!(email: "ada@census.test")
    token = user.access_token.token
    client = devise_client(c, user)
    anon = c::Client.new
    template = Template.order(:id).first!
    submission = template.submissions.order(:id).first!
    submitter = Submitter.where(completed_at: nil, template_id: template.id).order(:id).first!
    Submission.joins(:submitters).where("submitters.email LIKE 'census-api-%'").distinct.find_each(&:destroy)
    api = json_headers.merge("HTTP_X_AUTH_TOKEN" => token)
    n = [0]
    seq = [0]
    create = -> {
      anon.post("/api/submissions", headers: api, body: JSON.generate(template_id: template.id, send_email: true,
        submitters: [{ role: template.submitters.first["name"], email: "census-api-#{seq[0] += 1}@census.test" }]))
    }
    ops = [
      html(c, client, "GET templates dashboard", "/"),
      html(c, client, "GET submissions dashboard", "/submissions"),
      html(c, client, "GET template", "/templates/#{template.id}"),
      html(c, client, "GET submission", "/submissions/#{submission.id}"),
      html(c, anon, "GET signing form", "/s/#{submitter.slug}"),
      op(c, "GET api templates", :json) { anon.get("/api/templates", headers: api) },
      op(c, "GET api submissions", :json) { anon.get("/api/submissions", headers: api) },
      op(c, "GET api submission", :json) { anon.get("/api/submissions/#{submission.id}", headers: api) },
      op(c, "PUT api template", :json) {
        anon.put("/api/templates/#{template.id}", headers: api,
          body: JSON.generate(name: c.flip(n, "Census agreement A", "Census agreement B")))
      },
      op(c, "POST api submission", :json, &create),
      c.mail_op("deliver SubmitterMailer#invitation_email") { SubmitterMailer.invitation_email(submitter) },
    ]
    add_sidekiq_jobs(c, ops, c.sidekiq_jobs_from(&create))
  end

  # Mastodon: the OAuth REST API the web and mobile clients use, public HTML
  # profile/status pages, ActivityPub JSON, and the Sidekiq jobs a post pushes.
  def mastodon(c)
    Rack::Attack.enabled = false # external control: request throttles, as for Discourse
    # Mastodon's own per-account posting limit (300 per 3 h) counts in Redis
    # across runs; every run starts from zero and stays below it.
    RedisConnection.with { |r| r.scan_each(match: "rate_limit:*").to_a.each { r.del(_1) } }
    alice = Account.find_local!("alice")
    user = alice.user
    app = Doorkeeper::Application.find_by!(superapp: true)
    Doorkeeper::AccessToken.where(resource_owner_id: user.id, application: app).delete_all
    token = Doorkeeper::AccessToken.create!(application: app, resource_owner_id: user.id, scopes: "read write follow").token
    Status.where(account: alice).where("text LIKE 'Census op post%'").find_each { RemoveStatusService.new.call(_1) }
    status = Status.where(account: alice, reblog_of_id: nil, visibility: %i[public unlisted]).order(:id).first!
    other = Status.where.not(account: alice).where(reblog_of_id: nil, visibility: :public).order(:id).first!
    bob = Account.find_local!("bob")
    anon = c::Client.new
    client = c::Client.new
    api = bearer(token)
    n = [0]
    seq = [0]
    create = -> {
      client.post("/api/v1/statuses", headers: api,
        body: JSON.generate(status: "Census op post #{seq[0] += 1} #{Process.pid} #rails @bob", visibility: "public"))
    }
    ops = [
      html(c, anon, "GET profile", "/@alice"),
      html(c, anon, "GET status page", "/@alice/#{status.id}"),
      # The ActivityPub actor needs a signed fetch here; WebFinger is the public lookup before it.
      op(c, "GET webfinger", :json) { anon.get("/.well-known/webfinger?resource=acct:alice@localhost", headers: json_headers) },
      op(c, "GET home timeline", :json) { client.get("/api/v1/timelines/home", headers: api) },
      op(c, "GET public timeline", :json) { client.get("/api/v1/timelines/public?local=true", headers: api) },
      op(c, "GET account statuses", :json) { client.get("/api/v1/accounts/#{bob.id}/statuses", headers: api) },
      op(c, "GET status context", :json) { client.get("/api/v1/statuses/#{other.id}/context", headers: api) },
      op(c, "GET notifications", :json) { client.get("/api/v1/notifications", headers: api) },
      op(c, "POST favourite toggle", :json) {
        client.post("/api/v1/statuses/#{other.id}/#{c.flip(n, "favourite", "unfavourite")}", headers: api)
      },
      op(c, "POST status", :json, &create),
    ]
    add_sidekiq_jobs(c, ops, c.sidekiq_jobs_from(&create))
  end

  # Lago (usage billing, API only): the Bearer-key REST API, event ingestion,
  # customer upserts and the jobs they enqueue.
  def lago(c)
    org = Organization.order(:id).first!
    key = org.api_keys.order(:id).first!.value
    subscription = org.subscriptions.active.order(:id).first!
    customer = subscription.customer
    metric = subscription.plan.billable_metrics.order(:id).first || org.billable_metrics.order(:id).first!
    Event.where(organization_id: org.id).where("transaction_id LIKE 'census-%'").delete_all
    client = c::Client.new
    api = bearer(key)
    n = [0]
    seq = [0]
    event = -> {
      client.post("/api/v1/events", headers: api, body: JSON.generate(event: {
        transaction_id: "census-#{Process.pid}-#{seq[0] += 1}", external_subscription_id: subscription.external_id,
        code: metric.code, timestamp: Time.current.to_i, properties: { metric.field_name || "value" => 1 } }))
    }
    ops = [
      op(c, "GET customers", :json) { client.get("/api/v1/customers", headers: api) },
      op(c, "GET customer", :json) { client.get("/api/v1/customers/#{customer.external_id}", headers: api) },
      op(c, "GET plans", :json) { client.get("/api/v1/plans", headers: api) },
      op(c, "GET subscriptions", :json) {
        client.get("/api/v1/subscriptions?external_customer_id=#{customer.external_id}", headers: api)
      },
      op(c, "GET invoices", :json) { client.get("/api/v1/invoices", headers: api) },
      op(c, "GET billable metrics", :json) { client.get("/api/v1/billable_metrics", headers: api) },
      op(c, "GET current usage", :json) {
        client.get("/api/v1/customers/#{customer.external_id}/current_usage?external_subscription_id=#{subscription.external_id}", headers: api)
      },
      op(c, "POST customer upsert", :json) {
        client.post("/api/v1/customers", headers: api,
          body: JSON.generate(customer: { external_id: customer.external_id, name: c.flip(n, "Census A", "Census B") }))
      },
      op(c, "POST event", :json, &event),
    ]
    add_jobs(c, ops, c.jobs_from(&event))
  end

  # Discourse: server-rendered crawler HTML (the Ember browser pages need the
  # JS build), the JSON API the Ember client calls, and an API-key reply POST.
  def discourse(c)
    # External control, like config.hosts.clear: thousands of requests from one
    # client would otherwise hit Discourse's per-user and per-IP rate limits.
    RateLimiter.disable
    admin = User.find_by!(username: "census0")
    # The secret is readable only right after creation, so each setup replaces the key.
    ApiKey.where(user: admin, description: "census").destroy_all
    key = ApiKey.create!(user: admin, created_by: admin, description: "census")
    topic = Topic.where(archetype: "regular").where("title LIKE 'Census topic%'").order(:id).first!
    target = Topic.where(archetype: "regular").where("title LIKE 'Census topic%'").order(:id).second!
    Post.where(topic_id: target.id).where("raw LIKE 'Census op reply%'").find_each { PostDestroyer.new(admin, _1).destroy }
    bot = c::Client.new("HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")
    anon = c::Client.new
    api = json_headers.merge("HTTP_API_KEY" => key.key, "HTTP_API_USERNAME" => admin.username)
    seq = [0]
    reply = -> {
      anon.post("/posts.json", headers: api, body: JSON.generate(topic_id: target.id,
        raw: "Census op reply #{seq[0] += 1} #{Process.pid} with **bold** text and a mention of @census2"))
    }
    ops = [
      html(c, bot, "GET latest (crawler)", "/"),
      html(c, bot, "GET topic (crawler)", "/t/#{topic.slug}/#{topic.id}"),
      html(c, bot, "GET category (crawler)", "/c/#{topic.category.slug}/#{topic.category.id}"),
      op(c, "GET latest.json", :json) { anon.get("/latest.json", headers: json_headers) },
      op(c, "GET categories.json", :json) { anon.get("/categories.json", headers: json_headers) },
      op(c, "GET topic.json", :json) { anon.get("/t/#{topic.id}.json", headers: json_headers) },
      op(c, "GET user.json", :json) { anon.get("/u/census1.json", headers: json_headers) },
      op(c, "GET search.json", :json) { anon.get("/search.json?q=rails", headers: json_headers) },
      op(c, "POST reply (API key)", :json, &reply),
    ]
    add_sidekiq_jobs(c, ops, c.sidekiq_jobs_from(&reply))
  end

  # Loomio: the signed session cookie (Rails authentication generator style),
  # the v1 JSON API the Vue client uses, the Bearer user API and HTML pages.
  def loomio(c)
    Rack::Attack.enabled = false # external control: request throttles, as for Discourse
    user = User.find_by!(email: "ada@census.test")
    user.update_columns(api_key: SecureRandom.hex(16)) if user.api_key.blank?
    group = user.groups.order(:id).first!
    discussion = group.discussions.order(:id).first!
    poll = group.polls.order(:id).first!
    Comment.where(user: user).where("body LIKE 'Census op comment%'").delete_all
    session = user.sessions.create!(user_agent: c::UA, ip_address: "127.0.0.1")
    client = c::Client.new
    client.cookie(*c.signed_cookie(:session_id, session.id))
    token = client.csrf("/dashboard", required: false)
    api = json_headers(token)
    seq = [0]
    comment = -> {
      client.post("/api/v1/comments", headers: api,
        body: JSON.generate(comment: { body: "Census op comment #{seq[0] += 1}", parent_type: "Discussion", parent_id: discussion.id }))
    }
    ops = [
      html(c, client, "GET dashboard", "/dashboard"),
      html(c, client, "GET group", "/g/#{group.key}"),
      html(c, client, "GET discussion", "/d/#{discussion.key}"),
      op(c, "GET boot site", :json) { client.get("/api/v1/boot/site", headers: api) },
      op(c, "GET discussion.json", :json) { client.get("/api/v1/discussions/#{discussion.key}", headers: api) },
      op(c, "GET poll.json", :json) { client.get("/api/v1/polls/#{poll.key}", headers: api) },
      op(c, "GET notifications", :json) { client.get("/api/v1/notifications", headers: api) },
      op(c, "GET user API discussions", :json) {
        c::Client.new.get("/api/user0/discussions?group_id=#{group.id}", headers: bearer(user.api_key))
      },
      op(c, "POST comment", :json, &comment),
    ]
    add_jobs(c, ops, c.jobs_from(&comment))
  end

  # Sure (personal finance, the maintained Maybe fork): its own demo_data
  # generator, the signed session cookie for Turbo/HTML pages, and the
  # X-Api-Key REST API.
  def sure(c)
    Rack::Attack.enabled = false # external control: request throttles, as for Discourse
    user = User.find_by!(email: "user@example.com")
    ApiKey.where(user: user, name: "census").delete_all
    key = ApiKey.generate_secure_key
    ApiKey.create!(user: user, name: "census", display_key: key, scopes: ["read_write"], source: "web")
    account = user.family.accounts.where(accountable_type: "Depository").order(:id).first!
    # Clean up before choosing the entry: ids are UUIDs, so a previous run's
    # posted entry can sort first.
    Entry.where(account_id: account.id).where("name LIKE 'Census op txn%'").find_each(&:destroy)
    entry = account.entries.where(entryable_type: "Transaction").order(:id).first!
    session = user.sessions.create!(user_agent: c::UA, ip_address: "127.0.0.1")
    client = c::Client.new
    client.cookie(*c.signed_cookie(:session_token, session.id))
    token = client.csrf("/")
    api = json_headers.merge("HTTP_X_API_KEY" => key)
    n = [0]
    seq = [0]
    update = -> {
      client.patch("/transactions/#{entry.id}", headers: TURBO,
        params: { entry: { notes: c.flip(n, "Census note A", "Census note B") }, authenticity_token: token })
    }
    ops = [
      html(c, client, "GET dashboard", "/"),
      html(c, client, "GET accounts", "/accounts"),
      html(c, client, "GET account", "/accounts/#{account.id}"),
      html(c, client, "GET transactions", "/transactions"),
      html(c, client, "GET budget", "/budgets/#{Date.current.strftime("%b-%Y").downcase}"),
      op(c, "GET api accounts", :json) { client.get("/api/v1/accounts", headers: api) },
      op(c, "GET api transactions", :json) { client.get("/api/v1/transactions?account_id=#{account.id}", headers: api) },
      op(c, "PATCH transaction (turbo_stream)", :turbo, &update),
      op(c, "POST api transaction", :json) {
        client.post("/api/v1/transactions", headers: api, body: JSON.generate(transaction: {
          account_id: account.id, date: Date.current.iso8601, amount: "12.34", name: "Census op txn #{seq[0] += 1}",
          currency: account.currency, nature: "expense" }), expect: [200, 201])
      },
    ]
    add_jobs(c, ops, c.jobs_from(&update))
  end

  # CASA (rubyforgood): its own deterministic seeds, a real Devise sign-in as a
  # chapter admin, Pundit-scoped HTML pages, a case PATCH and its JSON form.
  def casa(c)
    Rack::Attack.enabled = false # external control: request throttles, as for Discourse
    admin = CasaAdmin.find_by!(email: "casa_admin1@example.com")
    casa_case = CasaCase.where(casa_org_id: admin.casa_org_id).active.order(:id).first!
    client = c::Client.new
    token = client.csrf("/users/sign_in")
    client.post("/users/sign_in", params: { user: { email: admin.email, password: "12345678" }, authenticity_token: token },
      expect: [302, 303])
    token = client.csrf("/casa_cases")
    # The edit form resubmits the case's contact types; admins must keep one.
    contact_type_ids = casa_case.contact_type_ids.presence || [ContactType.for_organization(admin.casa_org).order(:id).first!.id]
    n = [0]
    ops = [
      html(c, client, "GET dashboard", "/"),
      html(c, client, "GET casa cases", "/casa_cases"),
      html(c, client, "GET casa case", "/casa_cases/#{casa_case.to_param}"),
      html(c, client, "GET casa case edit", "/casa_cases/#{casa_case.to_param}/edit"),
      html(c, client, "GET volunteers", "/volunteers"),
      html(c, client, "GET supervisors", "/supervisors"),
      html(c, client, "GET case contacts", "/case_contacts"),
      # CasaCasesController#show has no JSON format; the mobile API sign-in is
      # CASA's JSON read (password check plus token blueprint).
      op(c, "POST api sign_in.json", :json) {
        client.post("/api/v1/users/sign_in", expect: 201, headers: json_headers,
          body: JSON.generate(email: admin.email, password: "12345678"))
      },
      op(c, "PATCH casa case (redirect)", :form) {
        client.patch("/casa_cases/#{casa_case.to_param}", expect: 302, params: {
          casa_case: { court_report_status: c.flip(n, "in_review", "submitted"), contact_type_ids: contact_type_ids },
          authenticity_token: token })
      },
      op(c, "PATCH casa case.json", :json) {
        client.patch("/casa_cases/#{casa_case.to_param}.json", headers: json_headers(token),
          body: JSON.generate(casa_case: { court_report_status: c.flip(n, "in_review", "submitted"), contact_type_ids: contact_type_ids }))
      },
    ]
    ops
  end
end

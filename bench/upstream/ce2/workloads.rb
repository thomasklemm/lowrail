# frozen_string_literal: true

require_relative "../census_4_workloads"

# CE2's heavier pages (bench/upstream/ce2/README.md), in
# censusce2 copies set up with bench/upstream/ce2/overlays and seed.rb. Same op
# contract as the census: each op does one ordinary operation and raises unless
# it succeeded; writes alternate between two values, so runs do not accumulate.
module Ce2Workloads
  module_function

  W = Census4Workloads

  # Blog: index pages of 50 and 100 articles with their comments (Destroy is a
  # button_to per article), the same 100 as JSON through the app's jbuilder
  # view and through as_json, and a 31-column customer: its edit page (22
  # fields, 3 button_to) and the save flow (the form's 22 params, two values change).
  def blog(c)
    client = c::Client.new
    customer = Customer.find_by!(account_number: "C-000001")
    edit = "/customers/#{customer.id}/edit"
    token = client.csrf(edit)
    form = customer.slice(%w[first_name last_name email phone company job_title website address_line1 address_line2
      city state postal_code country time_zone locale currency plan credit_limit birthday])
      .transform_values(&:to_s).merge("tax_exempt" => "0", "newsletter" => "1")
    n = [0]
    [
      W.html(c, client, "GET articles (50)", "/articles?per_page=50"),
      W.html(c, client, "GET articles (100)", "/articles?per_page=100"),
      W.op(c, "GET articles.json (100, jbuilder)", :json) { client.get("/articles.json?per_page=100", headers: W.json_headers) },
      W.op(c, "GET api/articles.json (100, as_json)", :json) { client.get("/api/articles.json?per_page=100", headers: W.json_headers) },
      W.html(c, client, "GET customer edit (form)", edit),
      W.op(c, "PATCH customer (save)", :form) {
        a = c.flip(n, true, false)
        params = form.merge("notes" => a ? "Prefers phone. Renewal in April." : "Prefers email. Renewal in March.",
          "city" => a ? "Chicago" : "Springfield")
        client.patch("/customers/#{customer.id}", params: { customer: params, authenticity_token: token }, expect: 303)
      },
    ]
  end

  # Lobsters, logged in: the newest page at 50 and 100 stories (the app's own
  # story list), newest.json at 100 (Story#as_json), and the settings page (its
  # three forms, about 30 fields). Saving settings is left out: a save with the
  # form's blank password fields rolls the session token and logs the user out.
  def lobsters(c)
    user = User.active.where(is_moderator: false).order(:id).first!
    user.update!(password: "census-password", password_confirmation: "census-password")
    client = c::Client.new
    token = client.csrf("/login")
    client.post("/login", params: { email: user.email, password: "census-password", authenticity_token: token },
      expect: 302)
    [
      W.html(c, client, "GET newest (50)", "/newest?per_page=50"),
      W.html(c, client, "GET newest (100)", "/newest?per_page=100"),
      W.op(c, "GET newest.json (100, as_json)", :json) { client.get("/newest.json?per_page=100", headers: W.json_headers) },
      W.html(c, client, "GET settings (form)", "/settings"),
    ]
  end

  # Fizzy, Kevin's cards index: geared pages 3 and 4 hold 50 and 100 cards
  # (assignees, tags, board, column), and page 4 as JSON through the app's
  # jbuilder views (json.cache! per card, as in production).
  def fizzy(c)
    identity = Identity.find_by!(email_address: "kevin@37signals.com")
    login = identity.sessions.create!
    client = c::Client.new
    client.cookie(*c.signed_cookie(:session_token, login.signed_id))
    account = identity.users.find_by!(name: "Kevin").account
    prefix = "/#{account.external_account_id}"
    check = ->(count) { ->(response) { raise "expected #{count} cards" unless response.body.scan(/"number":/).size >= count } }
    [
      W.html(c, client, "GET cards (50)", "#{prefix}/cards?page=3"),
      W.html(c, client, "GET cards (100)", "#{prefix}/cards?page=4"),
      W.op(c, "GET cards.json (100, jbuilder)", :json) {
        check.(100).(client.get("#{prefix}/cards.json?page=4", headers: W.json_headers))
      },
    ]
  end
  singleton_class.alias_method :fizzy_mysql, :fizzy
end

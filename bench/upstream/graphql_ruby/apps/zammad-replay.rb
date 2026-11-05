# Replays Zammad desktop-view GraphQL queries in-process (docs/upstream/graphql-ruby.md#zammad-replay).
# DATABASE_URL=postgres://postgres@127.0.0.1/zammad_replay bundle exec rails runner zammad-replay.rb MODE [N]
#   seed: adds agent@replay.test and 20 tickets with 5 articles each (once per database)
#   dump: writes every result as JSON to $DUMP;  run: executes the set N times after 3 warm-up rounds
#   wall: prints ms per round over N rounds;  stackprof: wall-mode profile of N rounds (STACKPROF_LIB=<gem>/lib,
#     STACKPROF_METHOD=name prints that method's callers and callees instead)
mode, n = ARGV[0], Integer(ARGV[1] || 1)
agent_login = "agent@replay.test"

if mode == "seed"
  UserInfo.current_user_id = 1
  agent = User.find_by(login: agent_login) || User.create!(login: agent_login, firstname: "Rita", lastname: "Replay", email: agent_login, password: "Replay-1234!",
    active: true, roles: Role.where(name: %w[Admin Agent]))
  agent.group_names_access_map = { "Users" => "full" }
  customer = User.find_by!(login: "nicole.braun@zammad.org")
  20.times do |i|
    next if Ticket.exists?(title: "Replay ticket #{i}")
    t = Ticket.create!(title: "Replay ticket #{i}", group: Group.find_by!(name: "Users"), customer:, owner: agent,
      state: Ticket::State.find_by!(name: i.even? ? "open" : "new"), priority: Ticket::Priority.find_by!(name: "2 normal"))
    t.tag_add("replay#{i % 3}", 1)
    5.times do |j|
      Ticket::Article.create!(ticket: t, from: customer.email, to: "support@example.com", subject: "Re: #{t.title}",
        body: "Body #{i}/#{j}\n" * 5, content_type: "text/plain", internal: j == 4,
        type: Ticket::Article::Type.find_by!(name: "note"), sender: Ticket::Article::Sender.find_by!(name: j.odd? ? "Agent" : "Customer"))
    end
  end
  puts "seeded: #{Ticket.count} tickets, #{Ticket::Article.count} articles"
  exit
end

root = Rails.root.join("app/frontend")
sources = Dir[root.join("**/*.graphql")].map { File.read(_1) }
fragments = {}
sources.each do |src|
  GraphQL.parse(src).definitions.grep(GraphQL::Language::Nodes::FragmentDefinition).each { fragments[_1.name] = _1 }
rescue GraphQL::ParseError
  next
end
operation = lambda do |name|
  src = sources.find { _1.match?(/^query #{name}\b/) } or raise "no query #{name}"
  doc = GraphQL.parse(src)
  needed = {}
  visit = lambda do |node|
    node.children.each { |c| c.is_a?(GraphQL::Language::Nodes::FragmentSpread) && !needed[c.name] ? (needed[c.name] = fragments.fetch(c.name); visit.(needed[c.name])) : visit.(c) }
  end
  doc.definitions.each(&visit)
  ([GraphQL::Language::Printer.new.print(doc)] + needed.values.map { GraphQL::Language::Printer.new.print(_1) }).join("\n")
end

agent = User.find_by!(login: agent_login)
ticket = Ticket.where(title: "Replay ticket 3").first!
overview = Ticket::Overviews.all(current_user: agent).first
gid = ->(o) { Gql::ZammadSchema.id_from_object(o) }
QUERIES = [
  ["session", {}], ["currentUser", {}], ["applicationConfig", {}],
  ["userCurrentTicketOverviews", { "ignoreUserConditions" => false, "withTicketCount" => true }],
  ["ticketsCachedByOverview", { "overviewId" => gid.(overview), "pageSize" => 30, "cacheTtl" => 3600 }],
  ["ticket", { "ticketId" => gid.(ticket) }],
  ["ticketArticles", { "ticketId" => gid.(ticket), "pageSize" => 20 }],
  ["userCurrentTaskbarItemList", { "app" => "desktop" }],
].map { |name, vars| [name, operation.(name), vars] }

controller = GraphqlController.new.tap { |c| c.request = ActionDispatch::Request.new({}); c.request.remote_ip = "127.0.0.1" }
UserInfo.current_user_id = agent.id
round = lambda do
  QUERIES.map do |name, query, vars|
    ctx = { sid: "0" * 32, current_user: UserContext.new(agent, nil), current_user_id: agent.id, controller: }
    [name, Gql::ZammadSchema.execute(query, variables: vars, context: ctx, operation_name: name).to_h]
  end
end

case mode
when "dump"
  File.write(ENV.fetch("DUMP"), JSON.pretty_generate(round.()))
  errs = round.().select { |_, r| r["errors"] }
  warn "queries with errors: #{errs.map(&:first).inspect}" if errs.any?
when "run"
  3.times { round.() }
  GC.start
  n.times { round.() }
when "wall"
  3.times { round.() }
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  n.times { round.() }
  printf "%.2f ms per round\n", (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000 / n
when "stackprof"
  $LOAD_PATH.unshift(ENV.fetch("STACKPROF_LIB")) # stackprof isn't in Zammad's bundle
  require "stackprof"
  3.times { round.() }
  prof = StackProf.run(mode: :wall, interval: 100) { n.times { round.() } }
  report = StackProf::Report.new(prof)
  ENV["STACKPROF_METHOD"] ? report.print_method(ENV["STACKPROF_METHOD"]) : report.print_text(false, 40)
  by_gem = Hash.new(0)
  prof[:frames].each_value { |f| by_gem[f[:file].to_s[%r{gems/([^/]+?)-\d[^/]*/}, 1] || f[:file].to_s[%r{zammad/(app|lib)/}] || "other"] += f[:samples] }
  by_gem.sort_by { -_2 }.first(15).each { printf "%-32s %5.1f%%\n", _1, 100.0 * _2 / prof[:samples] }
end

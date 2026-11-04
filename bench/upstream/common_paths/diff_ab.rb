require "bundler/setup"
require "action_controller"
require "useragent"

out = []
uas = {
  "firefox 132" => "Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0",
  "firefox 100" => "Mozilla/5.0 (X11; Linux x86_64; rv:100.0) Gecko/20100101 Firefox/100.0",
  "safari 18" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
  "safari 16" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15",
  "chrome 119" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
  "ie 11" => "Mozilla/5.0 (Windows NT 10.0; Trident/7.0; rv:11.0) like Gecko",
  "opera 105" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 OPR/105.0.0.0",
  "googlebot" => "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
  "empty" => "",
  "curl" => "curl/8.0",
}
mutated = { firefox: 100 }
sets = {
  ":modern" => :modern,
  "symbol keys" => { firefox: 133, safari: 17, chrome: false },
  "string keys" => { "firefox" => 133, "ie" => false },
  "HWIA" => ActiveSupport::HashWithIndifferentAccess.new(firefox: 133),
  "frozen custom" => { firefox: 120 }.freeze,
  "mutated between checks" => mutated,
  ":unknown" => :unknown,
  "nil" => nil,
}
B = ActionController::AllowBrowser::BrowserBlocker
sets.each do |sname, versions|
  uas.each do |uname, ua|
    env = Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => ua)
    r = begin
      b = B.new(ActionDispatch::Request.new(env), versions: versions)
      [b.blocked?, b.versions.equal?(versions)]
    rescue => e
      [e.class, e.message[0, 80]]
    end
    out << [sname, uname, r].inspect
  end
  mutated[:firefox] = 140 if sname == "mutated between checks"
end
uas.each do |uname, ua|
  env = Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => ua)
  out << ["mutated after", uname, B.new(ActionDispatch::Request.new(env), versions: mutated).blocked?].inspect
end
out << ["SETS", B::SETS, B::SETS.frozen?, B::SETS[:modern].frozen?, Ractor.shareable?(B::SETS)].inspect
controller = Class.new(ActionController::Base) do
  allow_browser versions: :modern, block: -> { head :not_acceptable }
  def index = render(plain: "ok")
  def self.name = "C"
end
events = []
ActiveSupport::Notifications.subscribe("browser_block.action_controller") { |*, p| events << p[:versions] }
uas.each do |uname, ua|
  env = Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => ua)
  status, _, body = controller.action(:index).call(env)
  out << ["request", uname, status].inspect
end
out << ["events", events].inspect
puts out

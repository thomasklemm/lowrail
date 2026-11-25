#!/usr/bin/env bash
# fresh_app.sh GEM APPDIR GEMHOME: thermos-fable's fresh app (M5 confirm, its receipts were not kept), rebuilt
# from its recipe on Ruby 4.0.7 / Rails 8.1.4: `rails new`, an isolated engine at /outsider, inline Active Job,
# a mailer, a channel, Minitest with two process workers, and lowrail-profile listed with require: false.
set -euo pipefail
gem=$1 app=$2 gh=$3
export GEM_HOME=$gh GEM_PATH=$gh PATH="$gh/bin:$(~/.local/bin/mise where ruby@4.0.7)/bin:$PATH" LOWRAIL_RAILS=8.1.4
unset RUBYOPT RUBYLIB BUNDLE_GEMFILE
rm -rf "$app"
gem install --local --no-document "$gem" > /dev/null
rails _8.1.4_ new "$app" --skip-git --skip-bundle --skip-javascript --skip-asset-pipeline --skip-hotwire --skip-jbuilder \
  --skip-action-mailbox --skip-action-text --skip-active-storage --skip-system-test --skip-rubocop --skip-brakeman \
  --skip-ci --skip-docker --skip-kamal --skip-solid --skip-thruster > /dev/null
cd "$app"
printf '\ngem "lowrail-profile", "0.1.0.rc1", group: [:development, :test], require: false\n' >> Gemfile
w() { mkdir -p "$(dirname "$1")"; cat > "$1"; }
w engines/outsider/lib/outsider/engine.rb <<'RUBY'
module Outsider
  class Engine < ::Rails::Engine
    isolate_namespace Outsider
  end
end
RUBY
w engines/outsider/config/routes.rb <<'RUBY'
Outsider::Engine.routes.draw do
  get "probe", to: "probe#index"
  get "probe/:id", to: "probe#show"
end
RUBY
w engines/outsider/app/controllers/outsider/probe_controller.rb <<'RUBY'
module Outsider
  class ProbeController < ActionController::Base
    def index
      TallyJob.perform_later(params[:tag] || "engine")
      render plain: "widgets #{Widget.count} #{Array.new(20) { |i| "w#{i}" }.join(",")}"
    end

    def show
      render json: { id: params[:id], name: Widget.find_by(id: params[:id])&.name }
    end
  end
end
RUBY
w config/routes.rb <<'RUBY'
Rails.application.routes.draw do
  mount Outsider::Engine => "/outsider"
  resources :widgets, only: %i[index show create]
end
RUBY
w app/models/widget.rb <<'RUBY'
class Widget < ApplicationRecord
  validates :name, presence: true
end
RUBY
w app/models/tally.rb <<'RUBY'
class Tally < ApplicationRecord; end
RUBY
w app/jobs/tally_job.rb <<'RUBY'
class TallyJob < ApplicationJob
  def perform(source)
    Tally.create!(source: source)
  end
end
RUBY
w app/controllers/widgets_controller.rb <<'RUBY'
class WidgetsController < ApplicationController
  skip_forgery_protection

  def index
    render json: Widget.order(:id).map { { id: _1.id, name: _1.name } }
  end

  def show
    render json: Widget.find(params[:id]).slice(:id, :name)
  end

  def create
    widget = Widget.create!(name: params.require(:name))
    TallyJob.perform_later("create-#{widget.name}")
    render json: { id: widget.id }, status: :created
  end
end
RUBY
w db/migrate/20261125000000_create_widgets.rb <<'RUBY'
class CreateWidgets < ActiveRecord::Migration[7.2]
  def change
    create_table(:widgets) { |t| t.string :name, null: false }
    create_table(:tallies) { |t| t.string :source }
  end
end
RUBY
w app/mailers/probe_mailer.rb <<'RUBY'
class ProbeMailer < ApplicationMailer
  def hello(tag) = mail(to: "a@example.com", from: "b@example.com", subject: "Hi #{tag}", body: "Hello")
end
RUBY
w app/channels/application_cable/connection.rb <<'RUBY'
module ApplicationCable
  class Connection < ActionCable::Connection::Base; end
end
RUBY
w app/channels/application_cable/channel.rb <<'RUBY'
module ApplicationCable
  class Channel < ActionCable::Channel::Base; end
end
RUBY
w app/channels/probe_channel.rb <<'RUBY'
class ProbeChannel < ApplicationCable::Channel
  def subscribed = stream_from("probe")
  def ping(data) = transmit({ pong: data["n"] })
end
RUBY
w config/cable.yml <<'YAML'
test:
  adapter: test
development:
  adapter: async
production:
  adapter: async
YAML
w test/outcome.rb <<'RUBY'
# One atomic line per test, whatever runs it: the per-test outcome to compare.
module Outcome
  def self.included(base)
    base.teardown { $stderr.write("OUTCOME #{self.class}##{name} #{skipped? ? "S" : passed? ? "." : error? ? "E" : "F"}\n") }
  end
end
ActiveSupport::TestCase.include(Outcome)
RUBY
w test/integration/outsider_test.rb <<'RUBY'
require "test_helper"
require_relative "../outcome"

class OutsiderTest < ActionDispatch::IntegrationTest
  setup do
    @tag = "t#{SecureRandom.hex(6)}"
    @widget = Widget.create!(name: @tag)
  end

  test "engine probe lists" do
    get "/outsider/probe"
    assert_response :success
    assert_match(/\Awidgets \d+ w0,w1/, response.body)
  end

  test "engine probe runs its job inline" do
    get "/outsider/probe", params: { tag: @tag }
    assert_equal 1, Tally.where(source: @tag).count
  end

  test "engine probe shows a widget" do
    get "/outsider/probe/#{@widget.id}"
    assert_equal @tag, response.parsed_body["name"]
  end

  test "engine probe shows nothing for a missing widget" do
    get "/outsider/probe/0"
    assert_nil response.parsed_body["name"]
  end

  test "widgets index" do
    get "/widgets"
    assert_includes response.parsed_body.map { _1["name"] }, @tag
  end

  test "widgets show" do
    get "/widgets/#{@widget.id}"
    assert_equal @tag, response.parsed_body["name"]
  end

  test "widgets create runs its job inline" do
    post "/widgets", params: { name: "#{@tag}-new" }
    assert_response :created
    assert Widget.exists?(name: "#{@tag}-new")
    assert_equal 1, Tally.where(source: "create-#{@tag}-new").count
  end

  test "a skipped test stays skipped" do
    skip "always"
  end
end
RUBY
w test/jobs/tally_job_test.rb <<'RUBY'
require "test_helper"
require_relative "../outcome"

class TallyJobTest < ActiveJob::TestCase
  test "a job outside a request" do
    tag = "j#{SecureRandom.hex(6)}"
    3.times { TallyJob.perform_now(tag) }
    assert_equal 3, Tally.where(source: tag).count
  end

  test "another job outside a request" do
    tag = "j#{SecureRandom.hex(6)}"
    2.times { TallyJob.perform_now(tag) }
    assert_equal 2, Tally.where(source: tag).count
  end
end
RUBY
w test/mailers/probe_mailer_test.rb <<'RUBY'
require "test_helper"
require_relative "../outcome"

class ProbeMailerTest < ActionMailer::TestCase
  test "a mail outside a request" do
    3.times { ProbeMailer.hello("m").deliver_now }
    assert_equal "Hi m", ActionMailer::Base.deliveries.last.subject
  end
end
RUBY
w test/channels/probe_channel_test.rb <<'RUBY'
require "test_helper"
require_relative "../outcome"

class ProbeChannelTest < ActionCable::Channel::TestCase
  test "a channel action outside a request" do
    subscribe
    3.times { |n| perform :ping, n: n }
    assert_equal({ "pong" => 2 }, transmissions.last)
  end
end
RUBY
ruby -e 's = File.read("config/application.rb"); s.sub!(/^module /) { "require_relative \"../engines/outsider/lib/outsider/engine\"\n\nmodule " } or abort "no module"; File.write("config/application.rb", s)'
ruby -e 's = File.read("config/environments/test.rb"); s.sub!(/^end\s*\z/) { "  config.active_job.queue_adapter = :inline\nend\n" } or abort; File.write("config/environments/test.rb", s)'
ruby -e 's = File.read("test/test_helper.rb"); s.sub!(/parallelize\(.*?\)/) { "parallelize(workers: 2, with: :processes, threshold: 0)" } or abort "no parallelize"; File.write("test/test_helper.rb", s)'
bundle install > bundle.log 2>&1
bin/rails db:migrate > /dev/null
git init -q && git add -A && git -c user.name=fresh -c user.email=fresh@example.invalid commit -qm "fresh app"
bundle exec ruby -e 'puts "ruby #{RUBY_VERSION}, rails #{Gem.loaded_specs["rails"].version}, lowrail-profile #{Gem.loaded_specs["lowrail-profile"].version}"'

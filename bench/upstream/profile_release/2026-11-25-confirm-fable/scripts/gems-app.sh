#!/usr/bin/env bash
# gems-app.sh RUBY : a copy of the fresh app with a GemsController (app/views/gems/index.html.erb) and
# app/models/gems/ruby.rb: where the report puts their lines.
set -uo pipefail
. "$(dirname "$0")/../env.sh" "$1"
rm -rf /tmp/pr2/gemsapp; cp -a /tmp/pr/a81/fresh /tmp/pr2/gemsapp; cd /tmp/pr2/gemsapp; rm -rf tmp/lp-* test/integration/hang_test.rb test/integration/probe_test.rb
mkdir -p app/views/gems app/models/gems
printf 'class GemsController < ApplicationController\n  def index\n    @names = Gems::Ruby.names\n  end\nend\n' > app/controllers/gems_controller.rb
printf 'module Gems\n  class Ruby\n    def self.names = Array.new(30) { |i| "gem#{i}" }\n  end\nend\n' > app/models/gems/ruby.rb
printf '<ul>\n<%% @names.each do |name| %%>\n  <li><%%= name.upcase %%></li>\n<%% end %%>\n</ul>\n' > app/views/gems/index.html.erb
ruby -pi -e 'sub(/^  resources :articles\n/, "  resources :articles\n  resources :gems, only: :index\n")' config/routes.rb
printf 'require "test_helper"\nclass GemsTest < ActionDispatch::IntegrationTest\n  %%w[a b c d e f].each { |n| test("gems #{n}") { get gems_url; assert_response :success } }\nend\n' > test/integration/gems_test.rb
PARALLEL_WORKERS=1 bundle exec lowrail-profile --top 400 --out tmp/lp-gems -- bin/rails test test/integration/gems_test.rb > /tmp/pr2/gemsapp.log 2>&1; echo "exit $?"
grep -n "Not attributed" tmp/lp-gems/report.md | cut -c1-330
ruby -rjson -e 'r = JSON.parse(File.read("tmp/lp-gems/report.json"))
  puts "unclassified: #{r["unclassified"].inspect[0, 300]}"
  puts "app lines: #{r["app_lines"].map { [_1["line"], _1["warm"], _1["own"]] }.select { |l, *| l =~ /gems/ }.inspect}"
  puts "ranked: #{r["ranked"].select { _1["site"] =~ %r{gems/(index|ruby)} }.map { [_1["site"], _1["group"], _1["all"]] }.inspect}"'

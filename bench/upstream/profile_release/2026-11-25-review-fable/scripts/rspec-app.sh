#!/usr/bin/env bash
# rspec-app.sh RUBY RAILS DIR : an RSpec app (rspec-rails, rswag-specs as Dawarich has) whose after(:suite) starts
# rspec and rake again; the nested rspec rewrites a tracked file in the order its examples ran.
set -euo pipefail
ruby=$1 rails=$2 dir=$3
here=$(cd "$(dirname "$0")" && pwd); . "$here/env.sh" "$ruby"
gem list -i lowrail-profile -v 0.1.0.rc1 >/dev/null || gem install --local --no-document "$GEMFILE_GEM"
mkdir -p "$(dirname "$dir")"; cd "$(dirname "$dir")"
rails "_${rails}_" new "$(basename "$dir")" -T --skip-kamal --skip-thruster --skip-docker --skip-ci --skip-rubocop --skip-brakeman --skip-bundler-audit >/tmp/pr/new-$(basename "$dir")-$ruby.log 2>&1
cd "$dir"
cat >> Gemfile <<'G'

group :development, :test do
  gem "rspec-rails"
  gem "rswag-specs"
  gem "lowrail-profile", require: false
end
G
bundle install >/dev/null
bin/rails g rspec:install >/dev/null
bin/rails g scaffold Article title:string body:text >/dev/null 2>&1
bin/rails db:migrate >/dev/null 2>&1
cp "$here/probes/probe.rb" spec/probe.rb
ruby -pi -e 'sub(/^require .rspec\/rails.\n/, %(require "rspec/rails"\nrequire_relative "probe"\nProbe.child("helper_load")\n))' spec/rails_helper.rb
cat >> spec/rails_helper.rb <<'R'
RSpec.configure do |config|
  config.after(:suite) do
    Probe.child("after_suite")
    Probe.env("after_suite_env")
    Probe.bundler("after_suite")
    # As Dawarich regenerates swagger.yaml: rspec again, which rewrites a tracked file.
    Probe.run("after_suite_nested_rspec", "bundle", "exec", "rspec", "spec/nested/order_spec.rb", "--require", "./spec/nested/writer")
    Bundler.with_unbundled_env do
      Probe.run("after_suite_nested_rspec_unbundled", { "WRITER_OUT" => "swagger/order_unbundled.txt" }, "bundle", "exec", "rspec", "spec/nested/order_spec.rb", "--require", "./spec/nested/writer")
    end
    Probe.run("after_suite_nested_rake", "bundle", "exec", "rake", "probe:env")
  end
end
R
mkdir -p spec/nested lib/tasks swagger
cat > spec/nested/writer.rb <<'R'
ran = []
RSpec.configure do |c|
  c.after(:each) { |e| ran << e.description }
  c.after(:suite) { File.write(ENV.fetch("WRITER_OUT", "swagger/order.txt"), ran.join("\n") + "\n") }
end
R
cat > spec/nested/order_spec.rb <<'R'
RSpec.describe "order" do
  %w[a b c d e f g h].each { |n| it(n) { expect(1).to eq(1) } }
end
R
cat > lib/tasks/probe.rake <<'R'
namespace :probe do
  task :env do
    puts ENV.keys.grep(/\ALOWRAIL|\A(?:SEED|SPEC_OPTS)\z/).sort.map { "#{_1}=#{ENV[_1]}" }
    puts "profiler=#{defined?(Lowrail::Profile).inspect}"
  end
end
R
mkdir -p spec/requests
cat > spec/requests/probe_spec.rb <<'R'
require "rails_helper"
RSpec.describe "probe", type: :request do
  it "starts a child in an example" do
    get articles_url
    expect(response).to be_successful
    Probe.child("in_example")
  end
end
R
bundle exec rspec spec/nested/order_spec.rb --require ./spec/nested/writer >/dev/null
WRITER_OUT=swagger/order_unbundled.txt bundle exec rspec spec/nested/order_spec.rb --require ./spec/nested/writer >/dev/null
git add -A && git -c user.name=x -c user.email=x@x commit -qm base
bundle exec rspec 2>&1 | tail -3

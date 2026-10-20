# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/lowrail/seal_static"

class SealTest < Minitest::Test
  include LowrailTest

  # Each negative differs in the condition the rule actually cares about, not
  # merely in a token unrelated to the positive. Hints assert no reachability.
  FIXTURES = {
    "SEAL001" => ["def run; C.define_method(:x) { 7 }; end", "class C; define_method(:x) { 7 }; end"],
    "SEAL002" => ["def default_url_options; {host: Current.host}; end", "def default_url_options; {host: 'example.org'}; end"],
    "SEAL003" => ["def to_param; slug; end", "def label; slug; end"],
    "SEAL004" => ["def run; ActiveSupport::Notifications.subscribe('render') {}; end", "def run; ActiveSupport::Notifications.instrument('render') {}; end"],
    "SEAL005" => ["def run; Rails.application.routes.draw {}; end", "def run; !Rails.application.config.nonce && config.adapter == 'sqlite3'; end"],
    "SEAL006" => ["def method_missing(name, *args); target.public_send(name, *args); end", "def label; target.label; end"],
    "SEAL007" => ["<%= item.name %>", "<%# locals: (item:) %><%= item.name %>"],
    "SEAL008" => ["def run; TagHelper::PRE_CONTENT_STRINGS.default = 'x'; end", "def run; TagHelper::PRE_CONTENT_STRINGS[:pre]; end"],
    "SEAL009" => ["def run; RubyVM::InstructionSequence.of(method(:label)); end", "def run; label; end"]
  }.freeze

  FIXTURES.each do |rule, (positive, negative)|
    define_method("test_#{rule}_positive_and_negative") do
      file = "/app/app/#{rule == 'SEAL007' ? 'views/row.html.erb' : 'models/example.rb'}"
      hints = Lowrail::SealStatic.source(positive, file: file, root: "/app")
      assert hints.any? { _1["rule"] == rule }, hints.inspect
      assert hints.all? { _1["confidence"] == "hint" && _1["origin"]["kind"] == "app" }
      refute Lowrail::SealStatic.source(negative, file: file, root: "/app").any? { _1["rule"] == rule }
    end
  end

  def test_initializer_subscription_and_gem_attribution
    hints = Lowrail::SealStatic.source("ActiveSupport::Notifications.subscribe('x') {}",
      file: "/app/config/initializers/events.rb", root: "/app")
    assert_empty hints
    spec = Struct.new(:name, :version, :full_gem_path).new("example", "1.2.3", "/gems/example")
    finding = Lowrail::SealRules.finding("SEAL001", confidence: "proven", file: "/gems/example/runtime.rb", line: 3, root: "/app", gems: [spec])
    assert_equal({"kind" => "gem", "name" => "example", "version" => "1.2.3"}, finding["origin"])
    assert_match(/upstream issue.*exclude/, finding["remedy"])
  end

  def test_post_seal_mutations_deopt_without_changing_stub_or_lexical_visibility
    Dir.mktmpdir do |dir|
      out, err, status = ruby("-I#{GEM_LIB}", "-e", <<~'RUBY', setup: false, env: {"OUTPUT" => dir})
        require 'json'
        require 'minitest/mock'
        require 'lowrail/seal'
        class Certified
          def value = 7
        end
        class Uncertified
          def value = 11
        end
        Lowrail::Seal.install(dir: ENV.fetch('OUTPUT'), targets: ['Certified'])
        Lowrail::Seal.activate
        Uncertified.define_method(:value) { 13 }
        raise 'uncertified singleton caught' unless Lowrail::Seal::EPOCH[0] == 0
        Lowrail::Seal.start_test('stub example')
        object = Certified.new
        object.stub(:value, 29) { raise 'stub changed' unless object.value == 29 }
        raise 'not restored' unless object.value == 7
        raise 'not deoptimized' unless Lowrail::Seal::EPOCH[0] > 0
        class Certified
          private
          def hidden = 31
        end
        raise 'lexical private changed' unless Certified.private_method_defined?(:hidden)
        Lowrail::Seal.finish_test
        Lowrail::Seal.start_test('later example')
        Lowrail::Seal.finish_test
        puts 'ok'
      RUBY
      assert status.success?, "#{out}\n#{err}"
      report = JSON.parse(File.read(Dir[File.join(dir, "seal-*.json")].fetch(0)))
      assert_equal "this test runs unoptimized", report["tests"]["stub example"]
      assert_equal "this test runs unoptimized", report["tests"]["later example"]
      assert report["ledger"].any? { _1["test_double"] && _1["rule"] == "SEAL001" }
      assert report["ledger"].all? { _1["confidence"] == "proven" && _1["line"].is_a?(Integer) }
    end
  end

  def test_framework_snapshot_detects_in_place_string_and_default_proc_changes
    Dir.mktmpdir do |dir|
      data = ruby_json(<<~'RUBY', setup: false, env: {"OUTPUT" => dir, "RUBYOPT" => "-I#{GEM_LIB}"})
        require 'json'
        require 'lowrail/seal'
        module ActionView
          module Helpers
            module TagHelper
              TAG_TYPES = { 'a' => :normal }.freeze
              PRE_CONTENT_STRINGS = Hash.new { |h, k| '' }.merge('pre' => "\n")
            end
          end
        end
        Lowrail::Seal.install(dir: ENV.fetch('OUTPUT'), targets: [])
        Lowrail::Seal.activate
        Lowrail::Seal.start_test('unchanged')
        Lowrail::Seal.finish_test
        raise 'unchanged tables deoptimized' unless Lowrail::Seal::EPOCH[0] == 0
        table = ActionView::Helpers::TagHelper::PRE_CONTENT_STRINGS
        table['pre'].replace('changed')
        table.default_proc = ->(*) { 'different' }
        Lowrail::Seal.start_test('changed')
        Lowrail::Seal.finish_test
        puts JSON.generate(Lowrail::Seal.ledger)
      RUBY
      assert data.any? { _1["rule"] == "SEAL008" && _1["operation"] == "snapshot_difference" }
    end
  end
end

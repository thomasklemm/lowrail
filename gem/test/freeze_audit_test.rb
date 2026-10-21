# frozen_string_literal: true

require_relative "test_helper"

class FreezeAuditTest < Minitest::Test
  include LowrailTest

  def test_enforcement_is_symmetric_and_records_rescued_mutations_despite_suppressed_hooks
    code = <<~'RUBY'
      require "lowrail/freeze_audit"
      module Dependency; def value = 7; end
      class Subject
        include Dependency
        def self.method_added(*) = nil
      end
      session = Lowrail::FreezeAudit::Session.new(profile: "holders", holders: [Subject])
      session.start!
      [-> { Subject.define_method(:value) { 8 } },
       -> { Dependency.send(:private, :value) },
       -> { Object.include(Module.new) },
       -> { Subject.instance_variable_set(:@memo, 1) },
       -> { Subject.define_singleton_method(:late) {} }].each do |mutation|
        begin; mutation.call; rescue FrozenError; end
      end
      object = Subject.new
      def object.value = 11
      result = [Subject.frozen?, Dependency.frozen?, Kernel.frozen?, BasicObject.frozen?, object.value]
      report = session.finish!
      report.delete("lowrail")
      puts JSON.generate([result, report])
    RUBY
    off = ruby_json(code, env: {"LOWRAIL" => "0", "LOWRAIL_FREEZE" => "1"})
    on = ruby_json(code, env: {"LOWRAIL" => "1", "LOWRAIL_FREEZE" => "1"})
    assert_equal off, on
    assert_equal [true, true, true, true, 11], off.first
    assert_equal 5, off.last.fetch("frozen_error_count")
    assert off.last.fetch("errors").all? { !_1.fetch("backtrace").empty? }
    assert_equal "violations_observed", off.last.fetch("status")
  end

  def test_without_explicit_switch_no_class_is_frozen
    result = ruby_json(<<~'RUBY', env: {"LOWRAIL_FREEZE" => nil})
      require "lowrail/freeze_audit"
      class Subject; end
      session = Lowrail::FreezeAudit::Session.new(profile: "holders", holders: [Subject]).start!
      Subject.define_method(:value) { 9 }
      puts JSON.generate([Subject.frozen?, Subject.new.value, session.finish!.fetch("status")])
    RUBY
    assert_equal [false, 9, "disabled"], result
  end

  def test_enforcement_without_audit_does_not_claim_observation
    result = ruby_json(<<~'RUBY', env: {"LOWRAIL" => "0", "LOWRAIL_FREEZE" => "1"})
      require "lowrail/freeze_audit"
      class Subject; end
      session = Lowrail::FreezeAudit::Session.new(profile: "holders", holders: [Subject]).start!(audit: false)
      blocked = begin; Subject.define_method(:late) {}; false; rescue FrozenError; true; end
      puts JSON.generate([blocked, session.finish!.fetch("status")])
    RUBY
    assert_equal [true, "enforced_without_observer"], result
  end

  def test_excluding_a_test_mixin_is_visible_and_never_claims_complete_ancestor_enforcement
    result = ruby_json(<<~'RUBY', env: {"LOWRAIL_FREEZE" => "1"})
      require "lowrail/freeze_audit"
      module TestMixin; def value = 7; end
      class Subject; include TestMixin; end
      session = Lowrail::FreezeAudit::Session.new(profile: "holders", holders: [Subject], exclusions: [TestMixin]).start!
      TestMixin.define_method(:value) { 11 }
      report = session.finish!
      puts JSON.generate([Subject.new.value, TestMixin.frozen?, report])
    RUBY
    assert_equal [11, false], result.first(2)
    assert_includes result.last.fetch("exclusions"), "TestMixin"
    assert_equal ["TestMixin"], result.last.fetch("excluded_required_holders")
    refute result.last.fetch("ancestor_closure_complete")
    assert_equal "no_violation_observed_with_exclusions", result.last.fetch("status")
  end

  def test_command_keeps_observer_through_framework_exit_workloads_and_covers_empty_classes
    realpath_tmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config/boot.rb"), "")
      File.write(File.join(dir, "config/environment.rb"), <<~'RUBY')
        class EmptySubject; end
        module Rails
          class Application
            def eager_load!; end
          end
          def self.application = @application ||= Application.new
        end
      RUBY
      File.write(File.join(dir, "workload.rb"), <<~'RUBY')
        raise "missing target" unless EmptySubject.frozen?
        raise "missing core" unless [Hash, Array, String, Enumerable].all?(&:frozen?)
        hash = {}; hash[:ordinary] = 7
        raise "ordinary Hash broken" unless hash[:ordinary] == 7
        at_exit do
          begin; EmptySubject.define_method(:late) {}; rescue FrozenError; end
        end
      RUBY
      script = File.expand_path("../script/freeze-audit", GEM_ROOT)
      output = File.join(dir, "audit.json")
      _, err, status = ruby(script, "core", output, "--", "workload.rb", chdir: dir, setup: false)
      assert_equal 1, status.exitstatus, err
      report = JSON.parse(File.read(output))
      assert_equal 1, report.fetch("frozen_error_count")
      assert report.fetch("workload_exit_ok")
      assert_includes report.fetch("holders"), "EmptySubject"
    end
  end
end

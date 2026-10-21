# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "json"
require "rbconfig"

class MethodSealTest < Minitest::Test
  def run_case(body)
    output, error, status = Open3.capture3(RbConfig.ruby, "-r#{File.expand_path('method_seal', __dir__)}", "-e", body)
    assert status.success?, error
    [JSON.parse(output.lines.last), error]
  end

  def test_class_memos_are_legal_and_callback_withdrawal_precedes_reentrant_app_code
    result, error = run_case(<<~'RUBY')
      class Subject
        def value = 7
        def self.method_added(*)
          $seen = $seal.active[0] if $seal
        end
      end
      $seal = MethodSeal::Session.new(holders: [Subject]).start!
      Subject.instance_variable_set(:@nil_memo, nil)
      Subject.instance_variable_set(:@false_memo, false)
      before = $seal.active[0]
      Subject.class_eval { def value = 19 }
      puts JSON.generate([before, $seen, Subject.new.value, $seal.finish!])
    RUBY
    assert_equal [true, false, 19], result.first(3)
    assert_equal "deoptimized", result.last.fetch("status")
    assert_includes error, "VIOLATION"
  end

  def test_saved_mutator_and_visibility_changes_deopt_without_changing_lexical_private
    ["saved.bind_call(Subject, :value) { 29 }", "Subject.class_eval { private; def hidden = 31 }"] .each do |mutation|
      result, = run_case(<<~RUBY)
        class Subject; def value = 7; end
        saved = Module.instance_method(:define_method)
        seal = MethodSeal::Session.new(holders: [Subject]).start!
        #{mutation}
        puts JSON.generate([seal.active[0], Subject.private_method_defined?(:hidden), seal.finish!])
      RUBY
      refute result.first
      assert_equal mutation.include?("private"), result[1]
    end
  end

  def test_undefined_callback_with_rescued_error_still_withdraws_the_changed_method
    result, = run_case(<<~'RUBY')
      class Subject
        def value = 7
        class << self; undef_method :method_added; end
      end
      seal = MethodSeal::Session.new(holders: [Subject]).start!
      begin; Subject.class_eval { def value = 43 }; rescue NoMethodError; end
      puts JSON.generate([seal.active[0], Subject.new.value, seal.finish!])
    RUBY
    assert_equal [false, 43], result.first(2)
    refute result.last.fetch("enforced")
  end
end

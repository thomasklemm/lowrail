# frozen_string_literal: true

require_relative "test_helper"

class JitDiagnosticsTest < Minitest::Test
  include LowrailTest

  def test_doctor_detects_disabled_global_boot_tracing_but_not_targeted_boot_tracing
    realpath_tmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config/environment.rb"), <<~'RUBY')
        module ThirdParty
          def self.boot = 29
        end
        case ENV["TRACE_MODE"]
        when "global", "targeted"
          trace = TracePoint.new(:return) {}
          ENV["TRACE_MODE"] == "global" ? trace.enable : trace.enable(target: ThirdParty.method(:boot))
          ThirdParty.boot
          trace.disable
        end
        RubyVM::YJIT.enable if ENV["TRACE_MODE"] == "late"
      RUBY
      %w[off targeted global no_stats interpreter late].each do |mode|
        flags = %w[interpreter late].include?(mode) ? "--disable-yjit" : "--yjit"
        flags += " --yjit-stats=quiet" unless %w[no_stats interpreter late].include?(mode)
        output = File.join(dir, "trace.json")
        args = [File.join(GEM_ROOT, "exe/lowrail-doctor-trace"), output]
        args << "--mode-only" if mode == "late"
        out, err, status = ruby(*args,
          setup: false, chdir: dir, env: {"RUBYOPT" => flags, "TRACE_MODE" => mode})
        assert status.success?, "#{mode}: #{err}#{out}"
        data = JSON.parse(File.read(output))
        if mode == "late"
          assert_equal "not_requested", data.fetch("status")
          assert_equal "interpreter", data.dig("jit_mode", "startup")
          assert_equal "yjit", data.dig("jit_mode", "after_initialize")
          assert_includes data.dig("jit_mode", "drift"), "interpreter -> yjit"
          next
        end
        if %w[no_stats interpreter].include?(mode)
          assert_equal "unavailable", data.fetch("status"), mode
          assert_nil data.fetch("leaf")
          next
        end
        assert_equal 0, data.fetch("enabled_tracepoints"), mode
        assert_equal true, data.dig("leaf", "yjit_compiled"), mode
        assert_equal(mode == "global" ? "warning" : "not_observed", data.fetch("status"), mode)
        assert_equal(mode == "global", data.fetch("global_return_tracing_suspected"), mode)
        assert_equal(mode == "global" ? 1000 : 0, data.dig("leaf", "exit_trace_leave_delta"), mode)
      end
    end
  end

  def test_request_only_targeted_tracing_is_not_mislabeled_as_global
    missing_prerequisite "Rack is not installed" if Gem::Specification.find_all_by_name("rack").empty?
    realpath_tmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config/environment.rb"), <<~'RUBY')
        module Rails
          class Application
            def leaf = 29
            def call(_env)
              100.times { leaf }
              [200, {"content-type" => "text/plain"}, ["ok"]]
            end
          end
          def self.application = @app ||= Application.new
        end
        $request_trace = TracePoint.new(:return) {}
        $request_trace.enable(target: Rails.application.method(:leaf))
      RUBY
      output = File.join(dir, "trace.json")
      out, err, status = ruby(File.join(GEM_ROOT, "exe/lowrail-doctor-trace"), output, "/probe",
        setup: false, chdir: dir, env: {"RUBYOPT" => "--yjit --yjit-stats=quiet"})
      assert status.success?, "#{err}#{out}"
      data = JSON.parse(File.read(output))
      assert_equal "warning", data.fetch("status")
      assert_equal false, data.fetch("global_return_tracing_suspected")
      assert_equal 0, data.dig("leaf", "exit_trace_leave_delta")
      assert_equal 200, data.dig("request", "status")
      assert_operator data.dig("request", "exit_trace_leave_delta"), :>, 0
    end
  end

  def test_doctor_warns_about_end_and_class_builtin_shapes_without_claiming_an_event_census
    realpath_tmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config/environment.rb"), <<~'RUBY')
        if ENV["TRACE_EVENT"] != "off"
          $trace = TracePoint.new(ENV.fetch("TRACE_EVENT").to_sym) {}
          $trace.enable
          if ENV["DISABLE_TRACE"] == "1"
            # Materialize under tracing, then keep that shape after disable.
            RubyVM::InstructionSequence.of(Symbol.instance_method(:to_s))
            $trace.disable
          end
        end
      RUBY
      %w[--disable-yjit --yjit].product(%w[off end class], %w[0 1]).each do |jit, event, disable|
        output = File.join(dir, "trace.json")
        out, err, status = ruby(File.join(GEM_ROOT, "exe/lowrail-doctor-trace"), output,
          setup: false, chdir: dir, env: {"RUBYOPT" => "#{jit} --yjit-stats=quiet",
            "TRACE_EVENT" => event, "DISABLE_TRACE" => disable})
        assert status.success?, "#{jit}/#{event}/#{disable}: #{err}#{out}"
        data = JSON.parse(File.read(output))
        builtins = data.fetch("builtin_dispatch")
        assert_equal(event == "off" ? "not_observed" : "warning", builtins.fetch("status"))
        if event == "off"
          assert_empty builtins.fetch("unfused")
        else
          assert_equal "warning", data.fetch("status")
          assert_includes builtins.fetch("unfused"), "Symbol#to_s"
          assert_includes data.fetch("reason"), "no event mask or guilty gem is identified"
        end
      end
    end
  end
end

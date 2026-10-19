# frozen_string_literal: true

# Generated-code capture (TracePoint(:script_compiled)) and its link to
# dumped methods, on plain Ruby in a subprocess (the capture is global).
#   ruby -Igem/lib -Igem/test gem/test/script_capture_test.rb

require "test_helper"
require "digest"

class ScriptCaptureTest < Minitest::Test
  include LowrailTest

  FIXTURE = <<~'RUBY'
    require "lowrail/script_capture"
    Lowrail::ScriptCapture.start(phase: "boot")
    require "lowrail/facts"

    module Gen
      class Target; end

      def self.define_readers(names)
        Target.class_eval names.map { |n| "def #{n}; @#{n}; end" }.join("\n"), __FILE__, __LINE__
      end
    end
    Gen.define_readers(%w[alpha beta])
    Gen::Target.class_eval <<~SRC, "gen/heredoc.rb", 10
      def gamma
        :gamma
      end
      define_method(:delta) { :delta }
    SRC
    Lowrail::ScriptCapture.phase = "later"
    eval "class Gen::Target; def epsilon; end; end"
    Gen::Target.new.instance_eval "def zeta; end"
    Gen::Target.class_eval { def plain; end }

    dir = ARGV[0]
    facts = Lowrail::Facts.collect(app_root: Dir.pwd, generated_dir: File.join(dir, "generated"))
    target = facts["modules"].find { |m| m["name"] == "Gen::Target" }
    ours = facts["generated_scripts"].select { |s| s["path"].include?("fixture.rb") || s["path"].start_with?("gen/") }
    puts JSON.generate("methods" => target["methods"], "scripts" => ours, "stats" => facts["generated_stats"])
  RUBY

  def test_scripts_are_captured_indexed_and_linked
    realpath_tmpdir do |dir|
      script = File.join(dir, "fixture.rb")
      File.write(script, FIXTURE)
      out, err, status = ruby("-I#{GEM_LIB}", script, dir, setup: false, chdir: dir)
      assert status.success?, err
      data = JSON.parse(out.lines.last)
      methods = data["methods"].to_h { |m| [m["name"], m] }
      scripts = data["scripts"]

      # Four scripts from our code: the generated readers, the heredoc, the
      # eval and the instance_eval (a block class_eval compiles nothing).
      assert_equal 4, scripts.size, scripts.inspect
      readers = scripts.find { |s| s["path"] == script }
      assert_equal "class_eval", readers["kind"]
      assert_equal "Gen::Target", readers["module"]
      assert_equal "Gen.define_readers", readers["caller_label"]
      assert_equal "#{script}:9", readers["caller"]
      assert_equal "boot", readers["phase"]
      assert_equal 2, readers["lines"]
      heredoc = scripts.find { |s| s["path"] == "gen/heredoc.rb" }
      assert_equal 10, heredoc["lineno"]
      evaled = scripts.find { |s| s["kind"] == "eval" }
      assert_equal "later", evaled["phase"]
      assert_equal "Object", evaled["module"]
      inst = scripts.find { |s| s["kind"] == "instance_eval" }
      assert_equal "Gen::Target", inst["module"]

      # Every script's source is in the sidecar under its digest.
      scripts.each do |s|
        file = File.join(dir, "generated", "#{s["sha256"]}.rb")
        assert_equal s["sha256"], Digest::SHA256.file(file).hexdigest
        assert_equal s["bytes"], File.size(file)
      end

      # Methods compiled inside a script carry its digest, including blocks
      # (define_method) and methods reported at the real file's line.
      assert_equal readers["sha256"], methods["alpha"]["script"]
      assert_equal readers["sha256"], methods["beta"]["script"]
      assert_equal heredoc["sha256"], methods["gamma"]["script"]
      assert_equal "gen/heredoc.rb:10", methods["gamma"]["source_location"]
      assert_equal heredoc["sha256"], methods["delta"]["script"]
      assert_equal evaled["sha256"], methods["epsilon"]["script"]
      assert_nil methods["plain"]["script"]
      assert_operator data["stats"]["compilations"], :>=, 4
    end
  end

  def test_capture_is_off_unless_started
    out, err, status = ruby("-I#{GEM_LIB}", "-e", <<~'RUBY', setup: false)
      require "lowrail/facts"
      class X; class_eval "def y; end"; end
      f = Lowrail::Facts.collect
      puts JSON.generate([f.key?("generated_scripts"), f["modules"].find { |m| m["name"] == "X" }["methods"][0].key?("script")])
    RUBY
    assert status.success?, err
    assert_equal [false, false], JSON.parse(out.lines.last)
  end
end

# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "tempfile"
require "open3"
require_relative "profile_summary"

class ProfileSummaryTest < Minitest::Test
  def test_recursive_frames_in_one_file_count_inclusive_cost_once
    profile = {"frames" => {
      "1" => {"file" => "/app/outer.rb", "line" => 1},
      "2" => {"file" => "/app/inner.rb", "line" => 2},
      "3" => {"file" => "/app/inner.rb", "line" => 9}
    }, "raw" => [4, 1, 2, 3, 2, 7, 1, 1, 3]}
    counts = ProfileSummary.counts(profile, "/app/")
    assert_equal 10, counts[:samples]
    assert_equal({"/app/outer.rb" => 10, "/app/inner.rb" => 7}, counts[:inclusive_by_file])
    assert_equal({"/app/outer.rb" => 3, "/app/inner.rb" => 7}, counts[:self_by_file])
  end

  def test_git_rails_and_generated_templates_keep_their_own_areas
    profile = {
      frames: {
        1 => { name: "controller", file: "/corpus/app/controllers/a.rb", line: 1 },
        2 => { name: "render", file: "/gems/rails-e3d5/actionview/lib/action_view/template.rb", line: 2 },
        3 => { name: "compiled_erb", file: "/corpus/app/views/a.html.erb", lines: { 8 => [1, 1] } },
        4 => { name: "String#append", file: "", line: nil }
      },
      raw: [3, 1, 2, 4, 3, 4, 1, 2, 3, 4, 1]
    }
    Tempfile.create do |file|
      file.write(JSON.generate(profile))
      file.flush
      output, status = Open3.capture2(RbConfig.ruby, File.join(__dir__, "profile_summary.rb"), file.path, "/corpus", "4")
      assert status.success?, output
      assert_match(/actionview\s+75.0%\s+100.0%/, output)
      assert_match(/erb\(app\)\s+25.0%\s+25.0%/, output)
      assert_match(/app\s+0.0%\s+100.0%/, output)
      assert_includes output, "compiled_erb (erb(app):generated)"
    end
  end
end

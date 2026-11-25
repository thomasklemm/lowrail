# frozen_string_literal: true

# The lowrail-profile gem as a stranger installs it: only the profiler's files
# (no lowering code), every file they require inside the package, the
# executable in one gem only, and the built gem running from a temporary gem
# home without this checkout.
#   ruby -Igem/lib -Igem/test gem/test/profile_package_test.rb

require "test_helper"

class ProfilePackageTest < Minitest::Test
  include LowrailTest

  SPEC = File.join(GEM_ROOT, "lowrail-profile.gemspec")
  PROFILER = %w[profile profile_report profile_compare profile_workloads profile_version workloads load_hooks loaded_constant]

  def spec = Gem::Specification.load(SPEC)

  def test_package_holds_only_the_profiler
    files = spec.files
    assert_equal PROFILER.map { "lib/lowrail/#{_1}.rb" }.sort, files.grep(%r{\Alib/}).sort
    refute files.include?("lib/lowrail.rb"), "the lowering runtime is not in the package"
    assert files.all? { File.file?(File.join(GEM_ROOT, _1)) }, (files.reject { File.file?(File.join(GEM_ROOT, _1)) }).inspect
    # Every require_relative of a packaged file resolves inside the package.
    files.grep(/\.rb\z|\Aexe\//).each do |file|
      File.read(File.join(GEM_ROOT, file)).scan(/require_relative\s+"([^"]+)"/).flatten.each do |target|
        path = File.expand_path("#{target}.rb", File.dirname(File.join(GEM_ROOT, file))).delete_prefix("#{GEM_ROOT}/")
        assert_includes files, path, "#{file} requires #{target}"
      end
    end
    assert_equal ["lowrail-profile"], spec.executables
    refute_includes Gem::Specification.load(File.join(GEM_ROOT, "lowrail.gemspec")).executables, "lowrail-profile"
    snapshot = JSON.parse(File.read(File.join(GEM_ROOT, "data/contributions-index.json")))
    assert_match(/\A\d{4}-\d\d-\d\d/, snapshot["generated"])
    refute_empty snapshot["pulls"]
  end

  # Bundler evaluates a path or git gem's gemspec in every app process.
  def test_evaluating_the_gemspec_loads_nothing
    out, err, status = ruby("-e", "Gem::Specification.load(#{SPEC.inspect}); p $LOADED_FEATURES.grep(/lowrail/)", setup: false)
    assert status.success?, err
    assert_equal "[]\n", out
  end

  def test_built_gem_runs_without_the_checkout
    Dir.mktmpdir("lowrail-profile-gem") do |dir|
      _, err, status = Open3.capture3(CLEAN_ENV, RUBY, "-S", "gem", "build", SPEC, "--output", File.join(dir, "p.gem"), chdir: GEM_ROOT)
      assert status.success?, err
      home = File.join(dir, "home")
      env = CLEAN_ENV.merge("GEM_HOME" => home, "GEM_PATH" => home, "RUBYLIB" => nil)
      _, err, status = Open3.capture3(env, RUBY, "-S", "gem", "install", "--local", "--no-document", File.join(dir, "p.gem"), chdir: dir)
      assert status.success?, err
      exe = File.join(home, "bin", "lowrail-profile")
      out, err, status = Open3.capture3(env, RUBY, exe, "--version", chdir: dir)
      assert status.success?, err
      assert_equal "lowrail-profile #{spec.version}\n", out
      out, _, status = Open3.capture3(env, RUBY, exe, "--help", chdir: dir)
      assert status.success?
      assert_includes out, "--allow-writes"
      # A capture from a gem home whose path has a space and glob characters: the counter builds, and the
      # child starts and loads the profiler.
      spaced = File.join(dir, "space [home] {x}*")
      _, err, status = Open3.capture3(env, RUBY, "-S", "gem", "install", "--local", "--no-document", "--install-dir", spaced,
        File.join(dir, "p.gem"), chdir: dir)
      assert status.success?, err
      env = env.merge("GEM_HOME" => spaced, "GEM_PATH" => spaced, "XDG_CACHE_HOME" => File.join(spaced, "cache"))
      out, err, = Open3.capture3(env, RUBY, File.join(spaced, "bin", "lowrail-profile"), "--runs", "1", "--out", "o", "--",
        RUBY, "-e", "puts defined?(Lowrail::Profile::API) ? :profiler_loaded : :profiler_missing", chdir: dir)
      assert_equal "profiler_loaded\n", out, err
      refute_match(/invalid switch/, err)
      installed = Dir[File.join(home, "gems", "lowrail-profile-*")].first
      refute File.exist?(File.join(installed, "lib/lowrail.rb"))
      assert File.file?(File.join(installed, "data/contributions-index.json"))
    end
  end
end

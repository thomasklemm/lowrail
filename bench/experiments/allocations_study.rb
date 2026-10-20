# frozen_string_literal: true

# Prepared production corpus only; creates no builds and never edits an app.
require "json"
require "fileutils"
require "rbconfig"

root = File.expand_path("../..", __dir__)
out = File.expand_path(ARGV.fetch(0))
raise "new output required" if File.exist?(out)
FileUtils.mkdir_p(out, mode: 0o700)
apps = {
  "blog" => ["real-blog-r4", { "index" => "/articles", "show" => "/articles/1", "edit" => "/articles/1/edit" }],
  "starter" => ["react-starter-kit", nil],
  "redprints" => ["redprints-alloc-r4", nil],
  "pingcrm" => ["pingcrm", nil]
}
apps.select! { |name, _| ARGV.drop(1).include?(name) } if ARGV.size > 1
apps.each do |label, (directory, paths)|
  app = File.join(root, ".corpus", directory)
  paths ||= JSON.parse(File.read(File.join(app, "tmp/m0/paths.json")))
  formats = label == "blog" ? ["html"] : %w[html json]
  formats.each do |format|
    headers = label == "blog" ? "{}" : File.read(File.join(app, "tmp/m0/headers-#{format}.json"))
    paths.each do |name, path|
      %w[off default].each do |arm|
        id = "#{label}-#{name}-#{format}-#{arm}"
        env = { "RAILS_ENV" => "production", "RAILS_LOG_LEVEL" => "error", "SECRET_KEY_BASE_DUMMY" => "1",
          "BENCH_JIT" => "1", "BENCH_WARMUP" => "400", "LOWRAIL" => arm == "off" ? "0" : "1",
          "RUBYOPT" => arm == "off" ? nil : "-I#{root}/gem/lib -rlowrail/setup",
          "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil, "LOWRAIL_ROOT" => app,
          "BENCH_HEADERS" => headers, "ALLOC_ROUTE" => path, "ALLOC_OUT" => File.join(out, id + ".json"),
          "ALLOC_SSR" => label == "starter" && format == "html" ? "1" : nil }
        raise "#{id} failed" unless system(env, RbConfig.ruby, "--yjit", File.join(__dir__, "allocations.rb"),
          chdir: app, out: File.join(out, id + ".log"), err: [:child, :out])
        if arm == "default"
          ids = JSON.parse(File.read(File.join(app, ".lowrail/manifest.json"))).fetch("units").map { _1.fetch("id") }
          probe = env.merge("LOWRAIL_STATS" => "1", "BENCH_UNITS" => ids.join(","))
          ok = system(probe, RbConfig.ruby, "--yjit", File.join(root, "bench/pass_probe.rb"), "GET:#{path}",
            chdir: app, out: File.join(out, id + "-probe.log"), err: [:child, :out])
          File.write(File.join(out, id + "-activation.json"), JSON.generate(strict_activation_passed: ok))
        end
        puts id
        $stdout.flush
      end
    end
  end
end

# Runs Gumroad's rspec suite without browser specs in N parallel processes, each with its own MySQL database,
# Elasticsearch indices (TEST_ENV_NUMBER, via the elasticsearch.rb shim) and DynamoDB table prefix; Redis blocks are
# leased by Gumroad's own config/test_redis_isolation.rb.
#
#   ruby gumroad-run.rb TREE_DIR LABEL SEED [WORKERS] [FILE...]
#
# Writes OUT/LABEL/worker-N.{json,log}; OUT defaults to /home/user/work/runs.
require "json"
require "fileutils"

tree, label, seed, workers, *files = ARGV
workers = (workers || 8).to_i
out = File.join(ENV.fetch("OUT", "/home/user/work/runs"), label)
FileUtils.mkdir_p(out)
db_prefix = ENV.fetch("DB_PREFIX") { "gr_#{File.basename(tree).tr('-', '_')}" }
excl = %w[--tag ~js --tag ~mobile_view --tag ~billy --tag ~tablet_view --tag ~skip]

Dir.chdir(tree)
files = Dir["spec/**/*_spec.rb"].sort if files.empty?
# Greedy split by file size, largest first.
groups = Array.new(workers) { [] }
loads = Array.new(workers, 0)
files.sort_by { -File.size(_1) }.each do |f|
  i = loads.index(loads.min)
  groups[i] << f
  loads[i] += File.size(f)
end

env_for = ->(n) {
  db = "#{db_prefix}_#{n}"
  { "TEST_ENV_NUMBER" => n.to_s, "DATABASE_NAME" => db, "TEST_DATABASE_NAME" => db,
    "DYNAMODB_TABLE_PREFIX" => "test_#{db_prefix}_#{n}_" }
}

if ENV["PREPARE"] == "1"
  pids = workers.times.map do |n|
    spawn(env_for.(n), "bundle exec rake db:drop db:setup", out: File.join(out, "prepare-#{n}.log"), err: [:child, :out])
  end
  pids.each { Process.wait(_1) }
end

started = Time.now
pids = groups.each_with_index.reject { |g, _| g.empty? }.map do |g, n|
  cmd = ["bundle", "exec", "rspec", "--seed", seed.to_s, *excl, "--format", "progress",
         "--format", "json", "--out", File.join(out, "worker-#{n}.json"), *g]
  spawn(env_for.(n), *cmd, out: File.join(out, "worker-#{n}.log"), err: [:child, :out])
end
pids.each { Process.wait(_1) }
elapsed = (Time.now - started).round

ex = []
outside = 0
Dir[File.join(out, "worker-*.json")].each do |j|
  data = JSON.parse(File.read(j)) rescue (warn "unreadable #{j}"; next)
  ex.concat(data["examples"])
  outside += data.dig("summary", "errors_outside_of_examples_count").to_i
end
failed = ex.select { _1["status"] == "failed" }
File.write(File.join(out, "failures.txt"), failed.map { "#{_1['id']}\t#{_1['full_description']}" }.sort.join("\n") + "\n")
summary = { label:, seed:, workers:, elapsed_s: elapsed, examples: ex.size,
            failed: failed.size, pending: ex.count { _1["status"] == "pending" },
            failed_files: failed.map { _1["file_path"] }.uniq.size, errors_outside_examples: outside,
            worker_json: Dir[File.join(out, "worker-*.json")].size }
File.write(File.join(out, "summary.json"), JSON.pretty_generate(summary))
puts summary.to_json

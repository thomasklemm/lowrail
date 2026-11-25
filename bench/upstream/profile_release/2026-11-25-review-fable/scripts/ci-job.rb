# ci-job.rb README REPO BASE_SHA HEAD_SHA SUMMARY : runs the README's GitHub Actions job step by step as the runner
# would: each `run` with `bash -e` (the default shell of a run step on Linux; `shell: bash` adds pipefail), the job's
# env, the two expressions substituted, and a step that fails stops the job. `uses:` steps are named, not run.
require "yaml"; require "open3"; require "tempfile"
readme, repo, base, head, summary = ARGV
job = YAML.safe_load(File.read(readme)[/```yaml\n(.*?)```/m, 1]).values.first
env = job.fetch("env", {}).transform_values(&:to_s).merge("GITHUB_STEP_SUMMARY" => summary, "CI" => "true")
File.write(summary, "")
job.fetch("steps").each do |step|
  if step["uses"]
    extra = step["uses"].start_with?("actions/upload-artifact") ? " -> #{Dir.glob(step.dig("with", "path"), base: repo).sort.inspect}" : ""
    puts "step uses #{step["uses"]} (not run)#{extra}"
    next
  end
  script = step.fetch("run").gsub("${{ github.event.pull_request.base.sha }}", base).gsub("${{ github.event.pull_request.head.sha }}", head)
  abort "unsubstituted expression in #{step["name"]}" if script.include?("${{")
  file = Tempfile.create(["step", ".sh"]); file.write(script); file.close
  shell = step["shell"] == "bash" ? %w[bash --noprofile --norc -eo pipefail] : %w[bash -e]
  out, status = Open3.capture2e(env, *shell, file.path, chdir: repo)
  File.write("#{summary}.#{step["name"].tr(" ", "-")}.log", out)
  puts "step #{step["name"].inspect}: exit #{status.exitstatus}"
  unless status.success?
    puts "JOB FAILED at #{step["name"].inspect}; later steps are skipped"
    exit 1
  end
end
puts "JOB SUCCEEDED"

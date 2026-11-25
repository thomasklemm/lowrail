# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "tmpdir"

class ForkHooksTest < Minitest::Test
  INSTALL = File.expand_path("../../script/install-fork-hooks", __dir__)
  GIT = File.executable?("/usr/bin/git") ? "/usr/bin/git" : "git"
  THOMAS = ["Thomas Klemm", "github@tklemm.eu"].freeze

  def git(dir, *args, author: THOMAS, committer: author)
    env = { "GIT_AUTHOR_NAME" => author[0], "GIT_AUTHOR_EMAIL" => author[1],
            "GIT_COMMITTER_NAME" => committer[0], "GIT_COMMITTER_EMAIL" => committer[1] }
    out, err, status = Open3.capture3(env, GIT, "-C", dir, *args)
    [out + err, status.success?]
  end

  def commit(dir, message, **who) = git(dir, "commit", "-q", "--allow-empty", "-m", message, **who)

  def test_refuses_only_new_commits_with_an_amp_trailer_or_another_identity
    Dir.mktmpdir do |tmp|
      remote, work = File.join(tmp, "remote.git"), File.join(tmp, "work")
      git(tmp, "init", "-q", "--bare", "-b", "main", remote)
      git(tmp, "clone", "-q", remote, work)
      commit(work, "theirs\n\nAmp-Thread-ID: T-1", author: ["Other", "o@o"])
      git(work, "push", "-q", "origin", "main")

      out, status = Open3.capture2e(INSTALL, work)
      assert status.success?, out
      assert_includes File.read(File.join(work, ".git/hooks/pre-push")), "Lowrail fork-pre-push"
      push = -> { git(work, "push", "-q", "origin", "HEAD:refs/heads/topic") }

      git(work, "checkout", "-q", "-b", "topic")
      commit(work, "ours")
      assert push.().last, "Thomas's commit on top of another author's pushed one"

      { "Amp-Thread-ID" => ["ours\n\nAmp-Thread-ID: T-2", {}],
        "Co-authored-by Amp" => ["ours\n\nCo-authored-by: Amp <amp@ampcode.com>", {}],
        "author" => ["ours", { author: ["Other", "o@o"], committer: THOMAS }],
        "committer" => ["ours", { committer: ["Thomas Klemm", "thomas@example.com"] }] }.each do |what, (message, who)|
        commit(work, message, **who)
        out, ok = push.()
        refute ok, what
        assert_match(/pre-push: \h+ ours has/, out, what)
        git(work, "reset", "-q", "--hard", "HEAD~")
      end
      commit(work, "ours\n\nCo-authored-by: Ada <ada@example.com>")
      assert push.().last, "a human co-author"
    end
  end

  def test_install_leaves_another_hook_alone
    Dir.mktmpdir do |dir|
      git(dir, "init", "-q")
      hook = File.join(dir, ".git/hooks/pre-push")
      File.write(hook, "#!/bin/sh\n")
      out, status = Open3.capture2e(INSTALL, dir)
      refute status.success?
      assert_match(/another hook/, out)
      assert_equal "#!/bin/sh\n", File.read(hook)
    end
  end
end

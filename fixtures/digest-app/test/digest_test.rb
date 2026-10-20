require_relative "../config/environment"
require "rails/test_help"
require "tmpdir"
require "fileutils"
require "digest"

class DigestContractTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir("digest-contract")
    @path = File.join(@directory, "manifest.json")
    @manifest = RailsVite::Manifest.new(@path)
  end

  teardown { FileUtils.remove_entry(@directory) }

  test "binary bytes, mutable results and same-size changes are observed" do
    bytes = "\x00\xff\xfealpha\n".b
    File.binwrite(@path, bytes)
    expected = Digest::MD5.hexdigest(bytes)
    3.times do
      actual = @manifest.digest
      assert_equal expected, actual
      assert_equal Encoding::US_ASCII, actual.encoding
      refute_predicate actual, :frozen?
      actual.replace("caller mutation")
    end
    2.times do
      descriptor = IO.sysopen(@path)
      assert_equal expected, RailsVite::Manifest.new(descriptor).digest
    end
    stamp = File.mtime(@path)
    bytes[-2] = "z"
    File.binwrite(@path, bytes)
    File.utime(stamp, stamp, @path)
    2.times { assert_equal Digest::MD5.hexdigest(bytes), @manifest.digest }
    encoded_path = @path.b + "\xff".b
    File.rename(@path, encoded_path)
    2.times { assert_equal Digest::MD5.hexdigest(bytes), RailsVite::Manifest.new(encoded_path).digest }
  end

  test "missing, recreated, empty, directory and unreadable files retain original behavior" do
    assert_same RailsVite::Manifest::NO_MANIFEST_DIGEST, @manifest.digest
    File.binwrite(@path, "")
    2.times { assert_equal "d41d8cd98f00b204e9800998ecf8427e", @manifest.digest }
    File.unlink(@path)
    assert_same RailsVite::Manifest::NO_MANIFEST_DIGEST, @manifest.digest
    File.binwrite(@path, "replacement")
    assert_equal Digest::MD5.hexdigest("replacement"), @manifest.digest
    File.chmod(0, @path)
    unless File.readable?(@path) # root can still read mode 0000
      expected = assert_raises(Errno::EACCES) { Digest::MD5.file(@path).hexdigest }
      actual = assert_raises(Errno::EACCES) { @manifest.digest }
      assert_equal expected.message, actual.message
    end
    File.chmod(0o600, @path)
    File.unlink(@path)
    Dir.mkdir(@path)
    expected = assert_raises(Errno::EISDIR) { Digest::MD5.file(@path).hexdigest }
    actual = assert_raises(Errno::EISDIR) { @manifest.digest }
    assert_equal expected.message, actual.message
  end

  test "changes between reads hash the open stream once and do not poison the next call" do
    old = "a" * 32_768 + "old tail"
    fresh = "b" * 32_768 + "new tail"
    %i[replace overwrite remove].each do |change|
      File.binwrite(@path, old)
      next_path = "#{@path}.next"
      File.binwrite(next_path, fresh)
      changed = false
      trace = TracePoint.new(:c_return) do |event|
        next unless event.method_id == :read && File === event.self && event.self.path == @path && !changed
        changed = true
        case change
        when :replace then File.rename(next_path, @path)
        when :overwrite then File.binwrite(@path, fresh)
        when :remove then File.unlink(@path)
        end
      end
      first = trace.enable { @manifest.digest }
      assert changed
      observed = change == :overwrite ? old.byteslice(0, 16_384) + fresh.byteslice(16_384..) : old
      assert_equal Digest::MD5.hexdigest(observed), first
      if change == :remove
        assert_same RailsVite::Manifest::NO_MANIFEST_DIGEST, @manifest.digest
      else
        2.times { assert_equal Digest::MD5.hexdigest(fresh), @manifest.digest }
      end
    end
  end

  test "files larger than the memo budget retain streaming digest semantics" do
    bytes = "large\x00\xff".b * 160_000
    File.binwrite(@path, bytes)
    2.times { assert_equal Digest::MD5.hexdigest(bytes), @manifest.digest }
  end

  test "watched globs retain additions, removals, ordering and the existing one-second window" do
    FileUtils.mkdir_p(File.join(@directory, "watched/nested"))
    File.binwrite(File.join(@directory, "vite.json"), "{}")
    File.binwrite(File.join(@directory, "watched/z.txt"), "z\xff".b)
    File.binwrite(File.join(@directory, "watched/nested/a.txt"), "a")
    make = -> { ViteRuby.new(root: @directory, source_code_dir: "watched", config_path: "vite.json") }
    expected = lambda do |paths|
      ids = paths.map { |path| "#{File.basename(path)}/#{Digest::SHA1.hexdigest(File.binread(File.join(@directory, path)))}" }
      Digest::SHA1.hexdigest(ids.join("/"))
    end
    paths = %w[vite.json watched/nested/a.txt watched/z.txt]
    travel_to(Time.utc(2026, 10, 20, 12)) do
      first = expected.call(paths)
      2.times { assert_equal first, make.call.digest }
      vite = make.call
      assert_equal first, vite.digest
      File.binwrite(File.join(@directory, "watched/b.txt"), "b")
      assert_equal first, vite.digest, "the existing time window must not be bypassed"
      travel 2.seconds
      paths.insert(1, "watched/b.txt")
      assert_equal expected.call(paths), vite.digest
      File.unlink(File.join(@directory, "watched/z.txt"))
      travel 2.seconds
      paths.pop
      2.times { assert_equal expected.call(paths), make.call.digest }
    end
  end

  test "a watched match removed after glob expansion raises instead of returning a stale digest" do
    FileUtils.mkdir_p(File.join(@directory, "watched"))
    File.binwrite(File.join(@directory, "vite.json"), "{}")
    path = File.join(@directory, "watched/a.txt")
    File.binwrite(path, "a")
    vite = ViteRuby.new(root: @directory, source_code_dir: "watched", config_path: "vite.json")
    vite.config.watched_paths
    removed = false
    trace = TracePoint.new(:return) do |event|
      next unless event.self == Dir && event.method_id == :[] && !removed
      removed = true
      File.unlink(path)
    end
    error = assert_raises(Errno::ENOENT) { trace.enable { vite.digest } }
    assert removed
    assert_includes error.message, "watched/a.txt"
  end
end

class VersionPageTest < ActionDispatch::IntegrationTest
  test "lazy Inertia version is recalculated and stale clients receive a location response" do
    path = RailsVite.config.manifest_path
    original = File.binread(path)
    begin
      version = Digest::MD5.hexdigest(original)
      3.times do
        get "/", headers: {"X-Inertia" => "true", "X-Inertia-Version" => version}
        assert_response :success
        page = JSON.parse(response.body)
        assert_equal "Page", page.fetch("component")
        assert_equal version, page.fetch("version")
        assert_equal "Hello", page.fetch("props").fetch("message")
      end
      File.binwrite(path, original.sub("entry-v1", "entry-v2"))
      get "/", headers: {"X-Inertia" => "true", "X-Inertia-Version" => version}
      assert_response :conflict
      assert_equal "http://www.example.com/", response.headers["X-Inertia-Location"]
      version = Digest::MD5.file(path).hexdigest
      2.times do
        get "/", headers: {"X-Inertia" => "true", "X-Inertia-Version" => version}
        assert_response :success
        assert_equal version, JSON.parse(response.body).fetch("version")
      end
    ensure
      File.binwrite(path, original)
    end
  end
end

# frozen_string_literal: true

# Plain Mash.new under YJIT after another Mash class ran first (screening, no A/A): which first class slows it.
# Usage: ruby --yjit -I HASHIE/lib yjit_first.rb VARIANT [TIMES [plain-first]]   (plain-first: plain Mash is compiled first)
#   A none, L empty subclass, B disable_warnings, C B plus a module overriding _log_collision?, E override calling
#   super, K override returning false, G PermissiveRespondTo, H custom_writer override calling super
require 'hashie'
require 'json'
require 'logger'
Hashie.logger = Logger.new(nil)
REPO = JSON.parse(File.read(File.expand_path('../fixtures/github-org-repos.json', __dir__))).first
module LC; private; def _log_collision?(k) = !self.class.disable_warnings?(k) && super; end
first =
  case ARGV.fetch(0)
  when 'A' then nil
  when 'L' then Class.new(Hashie::Mash)
  when 'B' then Class.new(Hashie::Mash) { disable_warnings }
  when 'C' then Class.new(Hashie::Mash) { disable_warnings; include LC }
  when 'E' then Class.new(Hashie::Mash) { private; def _log_collision?(k) = super }
  when 'K' then Class.new(Hashie::Mash) { private; def _log_collision?(_k) = false }
  when 'G' then Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::PermissiveRespondTo }
  when 'H' then Class.new(Hashie::Mash) { def custom_writer(k, v, c = true) = super }
  end
6000.times { Hashie::Mash.new(REPO) } if ARGV[2] == 'plain-first'
(ARGV[1] || 1).to_i.times { first.new(REPO) } if first
6000.times { Hashie::Mash.new(REPO) }
GC.start; GC.disable
w = Array.new(15) { t = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID); 400.times { Hashie::Mash.new(REPO) }; (Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) - t) * 1e6 / 400 }
puts format('%s x%s%s %.1f us', ARGV[0], ARGV[1] || 1, ARGV[2] ? " #{ARGV[2]}" : '', w.min)

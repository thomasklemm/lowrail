# RAILS=path ruby resolver_find_all_hook.rb
# Does a custom resolver's private _find_all still get called? One Resolver subclass and one
# FileSystemResolver subclass (the godmin/rbexy shape) override it; both look up "hello" through
# a lookup context (PathSet#find) and through find_all.
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[actionview activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
end
require "action_view"
require "tmpdir"

def template(source)
  ActionView::Template.new(source, "hook", ActionView::Template.handler_for_extension(:erb),
    locals: [], format: :html, virtual_path: "hooked/hello")
end

class HookResolver < ActionView::Resolver
  private def _find_all(name, prefix, partial, details, key, locals)
    name == "hello" ? [template("from Resolver#_find_all")] : []
  end
end

class FileSystemHookResolver < ActionView::FileSystemResolver
  private def _find_all(name, prefix, partial, details, key, locals)
    name == "hello" ? [template("from FileSystemResolver#_find_all")] : []
  end
end

failed = false
[HookResolver.new, FileSystemHookResolver.new(Dir.mktmpdir)].each do |resolver|
  lookup = ActionView::LookupContext.new([resolver])
  %i[find find_all].each do |method|
    found = Array(lookup.public_send(method, "hello", ["hooked"])).first
    puts "#{resolver.class.superclass.name.demodulize} #{method}: #{found&.source.inspect}"
    failed = true unless found
  rescue NotImplementedError, StandardError => error
    failed = true
    puts "#{resolver.class.superclass.name.demodulize} #{method}: #{error.class}: #{error.message.lines.first.strip}"
  end
end
exit(failed ? 1 : 0)

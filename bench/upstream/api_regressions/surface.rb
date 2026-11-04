# Dump the reflective API surface of the Rails frameworks in one tree.
# usage: ruby surface.rb RAILS_ROOT OUT.json
require "json"
root, out = ARGV
FW = %w[activesupport activemodel activerecord actionpack actionview actionmailer activejob actioncable
        activestorage actionmailbox actiontext railties]
FW.each { |f| $LOAD_PATH.unshift File.join(root, f, "lib") }
$VERBOSE = nil
ENV["RAILS_ENV"] = "test"

require "active_support/all"
require "rails/all"
FW.each { |f| begin; require f.sub("action", "action_").sub("active", "active_").sub(/_\z/, ""); rescue LoadError, StandardError; end }

failures = []
before = $LOADED_FEATURES.dup
FW.each do |f|
  libdir = File.join(root, f, "lib")
  Dir[File.join(libdir, "**/*.rb")].sort.each do |file|
    rel = file.delete_prefix(libdir + "/").delete_suffix(".rb")
    next if rel.include?("/templates/") || rel.include?("/tasks/")
    next if rel.match?(%r{\Arails/(commands|cli|app_loader|console|test_help|test_unit/runner|code_statistics|ruby_version_check)|autorun|minitest/|plugin\z|/command\z|\Aactive_record/railties/})
    begin
      require rel
    rescue Exception => e
      failures << [rel, e.class.name, e.message[0, 120]]
    end
  end
end

# Engine models under app/ need a full app; load what loads without one.
%w[activestorage actionmailbox actiontext].each do |f|
  Dir[File.join(root, f, "app/{models,jobs,controllers,helpers}/**/*.rb")].sort.each do |file|
    begin
      require file
    rescue Exception => e
      failures << [file.delete_prefix(root + "/"), e.class.name, e.message[0, 120]]
    end
  end
end

TOP = %w[ActiveSupport ActiveModel ActiveRecord ActionDispatch ActionController AbstractController ActionView ActionMailer
         ActiveJob ActionCable ActiveStorage ActionMailbox ActionText Rails Arel Mime]

def sig(m)
  m.parameters.map { |k, n| "#{k}:#{n}" }.join(",")
rescue StandardError
  "?"
end

def src(m)
  f, l = m.source_location
  f ? "#{f.sub(%r{\A.*?/(?=(?:active|action|railties)[a-z]*/(?:lib|app)/)}, "")}:#{l}" : nil
end

entries = {}
seen = {}
queue = TOP.filter_map { |n| Object.const_get(n) rescue nil }
until queue.empty?
  mod = queue.shift
  next if seen[mod.object_id]
  seen[mod.object_id] = true
  name = (Module.instance_method(:name).bind_call(mod) rescue nil)
  next unless name && TOP.any? { |t| name == t || name.start_with?("#{t}::") }
  kind = mod.is_a?(Class) ? "class" : "module"
  entries["#{name}"] = { "kind" => kind, "super" => (mod.is_a?(Class) ? mod.superclass&.name : nil),
    "all_i" => (mod.public_instance_methods(true) + mod.protected_instance_methods(true)).map(&:to_s).sort,
    "all_ip" => mod.private_instance_methods(true).map(&:to_s).sort,
    "all_s" => (mod.singleton_class.public_instance_methods(true) + mod.singleton_class.protected_instance_methods(true)).map(&:to_s).sort,
    "all_sp" => mod.singleton_class.private_instance_methods(true).map(&:to_s).sort,
    "ancestors" => mod.ancestors.filter_map { |x| Module.instance_method(:name).bind_call(x) rescue nil } }
  { "+" => :public_instance_methods, "#" => :protected_instance_methods, "-" => :private_instance_methods }.each do |vis, meth|
    mod.send(meth, false).each do |mn|
      um = mod.instance_method(mn)
      entries["#{name}##{mn}"] = { "vis" => vis, "sig" => sig(um), "src" => src(um) }
    end
  end
  sc = mod.singleton_class
  { "+" => :public_instance_methods, "#" => :protected_instance_methods, "-" => :private_instance_methods }.each do |vis, meth|
    sc.send(meth, false).each do |mn|
      um = sc.instance_method(mn)
      entries["#{name}.#{mn}"] = { "vis" => vis, "sig" => sig(um), "src" => src(um) }
    end
  end
  mod.constants(false).each do |c|
    v = begin
      mod.autoload?(c) ? (mod.const_get(c, false) rescue :autoload_failed) : mod.const_get(c, false)
    rescue Exception
      :error
    end
    if Module === v
      cname = (Module.instance_method(:name).bind_call(v) rescue nil)
      if cname == "#{name}::#{c}"
        queue << v
      else
        entries["#{name}::#{c}"] = { "kind" => "alias", "to" => cname }
      end
    else
      entries["#{name}::#{c}"] = { "kind" => "const", "class" => (Kernel.instance_method(:class).bind_call(v).name rescue "?") }
    end
  end
end

File.write(out, JSON.pretty_generate("entries" => entries, "failures" => failures))
puts "#{entries.size} entries, #{failures.size} load failures"

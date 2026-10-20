# frozen_string_literal: true

require "json"
require "digest"
require "prism"
require_relative "../lowrail"

module Lowrail
  module DigestMemoBuild
    PASS = "digest/file_memo"
    TARGETS = {
      "RailsVite::Manifest" => %i[digest watched_files_digest],
      "ViteRuby::Builder" => %i[watched_files_digest file_digest]
    }.freeze

    # Only replace the file-hash intrinsic. The gem retains its own rescues,
    # glob expansion/sorting, directory filtering, time window and stat cache.
    class Calls < Prism::Visitor
      attr_reader :calls

      def initialize
        @calls = []
      end

      def visit_call_node(node)
        file = node.receiver
        if node.name == :hexdigest && node.arguments.nil? && node.block.nil? && node.call_operator_loc&.slice == "." &&
            Prism::CallNode === file && file.name == :file && file.block.nil? && file.call_operator_loc&.slice == "." &&
            file.arguments&.arguments&.size == 1 &&
            ["Digest::MD5", "Digest::SHA1", "::Digest::MD5", "::Digest::SHA1"].include?(file.receiver&.location&.slice)
          arg = file.arguments.arguments.first
          @calls << [node, file.receiver.location.slice, arg.location.slice] unless Prism::SplatNode === arg || Prism::KeywordHashNode === arg
        end
        super
      end
    end

    class Definitions < Prism::Visitor
      attr_reader :definitions, :refined

      def initialize
        @definitions = []
        @refined = false
      end

      def visit_def_node(node)
        @definitions << node
        super
      end

      def visit_call_node(node)
        @refined = true if node.name == :using
        super
      end
    end

    module_function

    def run(input_path)
      input = JSON.parse(File.read(input_path))
      ledger_path = File.join(input.fetch("out"), "ledger.json")
      ledger = JSON.parse(File.read(ledger_path))
      denied_path = File.join(input.fetch("out"), "denylist.json")
      denied = File.file?(denied_path) ? JSON.parse(File.read(denied_path)) : []
      targets = TARGETS.flat_map do |name, methods|
        mod = Object.const_get(name)
        methods.filter_map { |method| [mod, mod.instance_method(method)] if mod.method_defined?(method) || mod.private_method_defined?(method) }
      rescue NameError
        []
      end
      targets.group_by { |_, method| method.source_location&.first }.each do |path, methods|
        next unless path && File.file?(path)
        original = File.read(path, encoding: Encoding::UTF_8)
        definitions = Definitions.new
        parsed = Prism.parse(original)
        next unless parsed.success?
        parsed.value.accept(definitions)
        calls = methods.flat_map do |_, method|
          definition = definitions.definitions.find { _1.name == method.name && _1.location.start_line == method.source_location[1] }
          visitor = Calls.new
          definition&.body&.accept(visitor)
          visitor.calls
        end.uniq { _1.first.location.start_offset }
        next if calls.empty?
        reason = "denylisted by verify --bisect" if denied.any? { _1["file"] == path && _1["pass"] == PASS }
        reason ||= "refined gem source" if definitions.refined
        reason ||= "multiline file digest intrinsic" if calls.any? { _1.first.location.start_line != _1.first.location.end_line }
        begin
          facts, sources = certify(calls.map { _1[1].delete_prefix("::") }.uniq)
        rescue ArgumentError => e
          reason ||= e.message
        end
        if reason
          ledger << {"file" => path, "pass" => PASS, "outcome" => reason}
          next
        end
        id = (input["units"].map { _1.fetch("id") }.max || -1) + 1
        lowered = original.b
        calls.sort_by { -_1.first.location.start_offset }.each do |node, algorithm, argument|
          replacement = "::Lowrail::DigestMemo.hexdigest(#{id}, #{algorithm}, #{argument})"
          lowered[node.location.start_offset, node.location.length] = replacement.b
          ledger << {"file" => path, "line" => node.location.start_line, "pass" => PASS, "outcome" => "lowered"}
        end
        lowered.force_encoding(Encoding::UTF_8)
        raise "digest lowering changed source lines" unless lowered.count("\n") == original.count("\n") && Prism.parse(lowered).success?
        dest = File.join(input.fetch("out"), "src", "digest__#{id}.rb")
        File.write(dest, lowered)
        File.write("#{dest}.orig", original)
        input["files"] << {"path" => path, "lowered" => dest, "original" => "#{dest}.orig"}
        input["units"] << {"id" => id, "kind" => "file", "file" => path, "pass" => PASS,
          "sites" => calls.size, "facts" => facts, "digest_memo" => {"sources" => sources,
            "algorithms" => calls.map { _1[1].delete_prefix("::") }.uniq}}
      end
      Lowrail.write_json(input_path, input)
      Lowrail.write_json(ledger_path, ledger)
      warn "[lowrail] digest/file_memo: #{ledger.count { _1["pass"] == PASS && _1["outcome"] == "lowered" }} sites"
    end

    def certify(algorithms)
      raise ArgumentError, "non-certified Digest version" unless Digest::VERSION == "3.2.1"
      facts = algorithms.flat_map do |name|
        klass = Object.const_get(name)
        raise ArgumentError, "non-native digest class" unless klass.superclass == Digest::Base
        expected = [[true, {file: Digest::Class.singleton_class, new: Class, hash: Kernel, eql?: Kernel}],
          [false, {initialize: Digest::Class, file: Digest::Instance, update: Digest::Base,
            hexdigest: Digest::Instance, initialize_clone: Kernel, initialize_copy: Digest::Base, finish: Digest::Base}]]
        expected.flat_map do |singleton, methods|
          methods.map do |method, owner|
            holder = singleton ? klass.singleton_class : klass
            raise ArgumentError, "custom digest method owner" unless holder.instance_method(method).owner.equal?(owner)
            fact(klass, method, singleton)
          end
        end
      end
      facts.concat([fact(File, :open, true), fact(File, :read, false)])
      facts.concat(%i[== << bytesize hash b +@ dup freeze initialize_dup initialize_copy].map { fact(String, _1, false) })
      facts.concat(%i[hash eql?].map { fact(Array, _1, false) })
      path_method = Pathname.instance_method(:to_path)
      raise ArgumentError, "custom path coercion" unless path_method.owner == Pathname && path_method.original_name == :to_s &&
        (path_method.source_location.nil? || path_method.source_location.first == "<internal:pathname_builtin>")
      path_fact = fact(Pathname, :to_path, false)
      facts << path_fact
      ruby_methods = [Digest::Class.method(:file), Digest::Instance.instance_method(:file)]
      expected = [
        'def self.file(name, *args); new(*args).file(name); end',
        'def file(name); File.open(name, "rb") {|f| buf = ""; while f.read(16384, buf); update buf; end }; self; end'
      ]
      ruby_methods.zip(expected).each do |method, body|
        path, line = method.source_location
        definitions = Definitions.new
        Prism.parse_file(path).value.accept(definitions)
        definition = definitions.definitions.find { _1.name == method.name && _1.location.start_line == line }
        # Token comparison ignores whitespace/comments, not literals or calls.
        tokens = ->(source) { Prism.lex(source).value.reject { |token, _| %i[COMMENT NEWLINE IGNORED_NEWLINE SEMICOLON EOF].include?(token.type) }.map { |token, _| [token.type, token.value] } }
        raise ArgumentError, "non-certified Digest file implementation" unless definition && tokens.call(definition.location.slice) == tokens.call(body)
      end
      facts.each do |entry|
        next if entry.equal?(path_fact)
        raise ArgumentError, "aliased digest/IO method" unless entry["original_name"] == entry["method"]
        next if entry["method"] == "file"
        raise ArgumentError, "non-native digest/IO method" if entry["source_location"]
      end
      paths = ruby_methods.map { _1.source_location.first } +
        $LOADED_FEATURES.select { _1.end_with?("/digest.so", "/digest/md5.so", "/digest/sha1.so") }
      sources = paths.uniq.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
      [facts.uniq, sources]
    end

    def fact(mod, name, singleton)
      holder = singleton ? mod.singleton_class : mod
      method = holder.instance_method(name)
      owner = method.owner.name || "#<Class:#{method.owner.attached_object.name}>"
      {"receiver" => mod.name, "method" => name.to_s, "singleton" => singleton, "exact" => true,
       "owner" => owner, "source_location" => method.source_location&.join(":"), "original_name" => method.original_name.to_s,
       "visibility" => holder.public_method_defined?(name) ? "public" : (holder.protected_method_defined?(name) ? "protected" : "private")}
    end
  end
end

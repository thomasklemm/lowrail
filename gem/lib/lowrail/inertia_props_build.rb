# frozen_string_literal: true

require "digest"
require "prism"
require_relative "inertia_props"
require_relative "preload_facts"

module Lowrail
  module InertiaPropsBuild
    PASS = Passes::InertiaProps::PASS
    AUDITED = {
      "3.21.2" => "48957d68dc3b619ca5a9de807c74ab12d425304592b410a95684d0bd89be32af",
      "3.22.0" => "48957d68dc3b619ca5a9de807c74ab12d425304592b410a95684d0bd89be32af",
      "3.23.0" => "bae893ce831a729869958803f6044fa25302ff51a89c6d103b7894f6aa36bc07"
    }.freeze

    class Definitions < Prism::Visitor
      attr_reader :nodes
      def initialize = @nodes = []
      def visit_def_node(node)
        @nodes << node
        super
      end
    end

    def self.build(denied: [])
      target = "InertiaRails::PropsResolver#deep_transform_props"
      entry = {"pass" => PASS, "method" => target, "helper" => "deep_transform_props"}
      units, files = [], []
      reason = catch(:refused) do
        decline = ->(code) { throw :refused, code }
        spec = Gem.loaded_specs["inertia_rails"]
        decline.call("gem_absent") unless spec && defined?(::InertiaRails::PropsResolver)
        decline.call("unsupported_gem_version") unless AUDITED.key?(spec.version.to_s)
        path = spec.full_gem_path + "/lib/inertia_rails/props_resolver.rb"
        decline.call("denylisted") if denied.any? { _1["pass"] == PASS && [target, path].include?(_1["target"] || _1["file"]) }
        original = File.read(path, encoding: Encoding::UTF_8)
        decline.call("source_changed") unless Digest::SHA256.hexdigest(original) == AUDITED.fetch(spec.version.to_s)
        klass = ::InertiaRails::PropsResolver
        decline.call("resolver_override") unless klass.private_method_defined?(:deep_transform_props)
        method = klass.instance_method(:deep_transform_props)
        definitions = Definitions.new
        Prism.parse(original).value.accept(definitions)
        node = definitions.nodes.find { _1.name == :deep_transform_props }
        decline.call("resolver_override") unless node && method.owner.equal?(klass) &&
          method.original_name == :deep_transform_props && method.source_location == [path, node.location.start_line]
        dependencies = [[Hash, :each, Hash], [Hash, :each_with_object, Enumerable]]
        facts = dependencies.map do |receiver, name, owner|
          decline.call("iteration_override") unless receiver.public_method_defined?(name)
          m = receiver.instance_method(name)
          decline.call("iteration_override") unless m.owner.equal?(owner) && m.source_location.nil? &&
            m.original_name == name
          PreloadFacts.method_fact(receiver, name, singleton: false).merge("exact" => true)
        end
        # Reuse the existing gem-source/ISeq delivery seam. Both arms retain
        # the original lexical scope and dynamic calls. There is NO captured
        # helper body or entry authorization reused after app code: each new
        # traversal checks its own actual iterator, including recursive calls.
        body = node.body.location.slice
        needle = "props.each_with_object({}) do |(key, prop), transformed_props|"
        raise "unknown audited iterator" unless body.start_with?(needle)
        fast = body.sub(needle, "transformed_props = {}; props.each do |key, prop|")
        fast = fast.lines.reject { _1.lstrip.start_with?("#") }.map(&:strip).reject(&:empty?).join("; ")
        header_end = original.b.index("\n", node.location.start_offset)
        parts = [original.byteslice(0...header_end), "; if ::Lowrail::Passes::InertiaProps.valid?(", 0,
          ", props); #{fast}; transformed_props; else",
          original.byteslice(header_end...node.end_keyword_loc.start_offset), "end; ",
          original.byteslice(node.end_keyword_loc.start_offset..)]
        lowered = parts.map { Integer === _1 ? "0" : _1 }.join
        raise "invalid prop lowering" unless Prism.parse(lowered).success? && lowered.count("\n") == original.count("\n")
        sources = [path, __FILE__, File.join(__dir__, "inertia_props.rb")].to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
        files << {path: path, original: original, parts: parts}
        units << {"pass" => PASS, "kind" => "file", "target" => target, "file" => path,
          "sites" => 1, "facts" => facts, "data" => {"gem_version" => spec.version.to_s, "sources" => sources}}
        nil
      end
      entry["outcome"] = reason || "lowered"
      {units: units, ledger: [entry], files: files}
    end
  end
end

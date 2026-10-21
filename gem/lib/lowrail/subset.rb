# frozen_string_literal: true

require "json"
require "digest"
require_relative "prism_grammar"
require_relative "seal_static"

module Lowrail
  # Advisory source + boot inventory. This is not an authorization certificate.
  # In particular, unknown dispatch is never promoted to purity or compliance.
  module Subset
    RULES = {
      "SUB001" => ["Fixed code/config after readiness", "Accept SEAL001/004/005/008/009; run seal-check with the app suite. Restart to change code/config.", "Entry/body/epoch revalidation; does not certify mutable receivers or data.", "large"],
      "SUB002" => ["Finite dispatch", "Replace computed send/eval with explicit branches or a finite literal dispatch table.", "SEAL006 and unresolved receiver/target guards.", "large"],
      "SUB003" => ["Finite callback chain", "Keep security callbacks; extract Proc/around callbacks into named, explicitly ordered before/after methods for this prototype.", "Callback interpreter only, never callback bodies or authorization.", "large"],
      "SUB004" => ["Explicit template inputs", "Declare strict locals (including locals: () for no locals); pass partial inputs explicitly.", "SEAL007 and repeated locals-shape/template lookup certification.", "small"],
      "SUB005" => ["No helper/template assign mutation", "Compute assigns in the controller; return helper values or use explicit content_for instead of mutating view ivars.", "Mid-render assign effects that invalidated handwritten endpoint ceilings.", "large"],
      "SUB006" => ["Finite synchronous render graph", "Name each partial/layout explicitly; keep cache, streaming, components and unknown renderers on stock Rails until supported.", "Resolver/handler/collection dispatch; cached rendering is NOT disabled.", "large"],
      "SUB007" => ["Static AR query structure", "Use named scopes with bound values and fixed table/association names; retain real AR callbacks, casts and queries.", "Query-shape/reflection guards only; does not license direct ivar reads or SQL/result caching.", "large"],
      "SUB008" => ["Closed source boundary", "Supply boot facts and source for generated/inherited targets; certify helper/gem effects separately or leave the call live.", "Unknown method/type/effect boundaries; observed types alone are not proof.", "large"]
    }.transform_values { |title, rewrite, removes, effort| {"title" => title, "rewrite" => rewrite, "removes" => removes, "effort" => effort} }.freeze

    class Scan < Prism::Visitor
      attr_reader :calls, :writes, :constants
      def initialize
        @calls, @writes, @constants = [], [], []
      end
      def visit_call_node(node)
        @calls << node
        super
      end
      def visit_constant_read_node(node)
        @constants << node.name.to_s
        super
      end
      %i[instance_variable_write instance_variable_or_write instance_variable_and_write
        instance_variable_operator_write instance_variable_target].each do |kind|
        define_method("visit_#{kind}_node") { |node| @writes << node; super(node) }
      end
    end

    class Index < Prism::Visitor
      attr_reader :methods, :classes, :errors, :files, :seal_hints
      def initialize(root)
        @root, @methods, @classes, @errors, @files = root, {}, {}, [], {}
        @seal_hints = {}
        @stack, @visibility = [], :public
        Dir.glob("#{root}/app/**/*.rb").sort.each do |file|
          @file = file
          source = File.read(file)
          @files[file] = Digest::SHA256.hexdigest(source)
          parsed = Prism.parse(source, version: PrismGrammar.version)
          if parsed.success?
            @seal_hints[file] = SealStatic.source(source, file: file, root: root)
            parsed.value.accept(self)
          else
            @errors << {"file" => file, "error" => parsed.errors.first.message}
          end
        end
      end
      def visit_class_node(node)
        name = node.constant_path.location.slice
        name = [@stack.last, name].compact.join("::") unless name.include?("::")
        @classes[name] = {"superclass" => node.superclass&.location&.slice, "file" => @file}
        enter(name) { super }
      end
      def visit_module_node(node)
        name = node.constant_path.location.slice
        name = [@stack.last, name].compact.join("::") unless name.include?("::")
        enter(name) { super }
      end
      def enter(name)
        previous, @visibility = @visibility, :public
        @stack << name
        yield
      ensure
        @stack.pop
        @visibility = previous
      end
      def visit_def_node(node)
        return if @stack.empty? || node.receiver
        scan = Scan.new
        node.body&.accept(scan)
        @methods[[@stack.last, node.name.to_s]] = {"file" => @file, "line" => node.location.start_line,
          "visibility" => @visibility, "node" => node, "scan" => scan}
        # Nested definitions are not normal call-graph edges.
      end
      def visit_call_node(node)
        @visibility = node.name if !node.receiver && !node.arguments && %i[private protected public].include?(node.name)
        super
      end
    end

    def self.finding(rule, file, line, detail)
      {"rule" => rule, **RULES.fetch(rule), "file" => file, "line" => line, "detail" => detail}
    end

    class Report
      def initialize(root, boot: nil, boot_error: nil)
        @root, @boot, @boot_error = File.expand_path(root), boot, boot_error
        @index = Index.new(@root)
        @templates = {}
      end

      def run
        controllers = if @boot
          @boot.fetch("controllers").filter_map do |row|
            next unless @index.classes.dig(row.fetch("name"), "file")&.include?("/app/controllers/")
            # action_methods can contain dozens of public Turbo/tag helpers.
            # Count route defaults and directly declared controller actions,
            # not every inherited helper as a hypothetical HTTP endpoint.
            routed = @boot.fetch("routes", []).filter_map { _1["action"] if _1["controller"] == row["controller_path"] }
            declared = @index.methods.filter_map { |(owner, name), method| name if owner == row["name"] && method["visibility"] == :public }
            row.merge("actions" => (routed + (declared & row.fetch("actions"))).uniq.compact)
          end
        else
          @index.classes.filter_map do |name, row|
            next unless row["file"].include?("/app/controllers/") && name.end_with?("Controller") && name != "ApplicationController"
            {"name" => name, "actions" => @index.methods.filter_map { |(owner, method), entry| method if owner == name && entry["visibility"] == :public }, "callbacks" => nil}
          end
        end
        actions = controllers.flat_map do |controller|
          controller.fetch("actions").sort.map { |action| action_report(controller, action) }
        end.sort_by { _1.fetch("target") }
        {"format" => 1, "tier" => "subset_exploration", "rules" => RULES, "ruby" => RUBY_DESCRIPTION,
          "root" => @root, "boot" => @boot, "boot_error" => @boot_error,
          "template_scope" => "HTML ERB only; JSON, Turbo Stream and other formats are not assessed",
          "inventory" => @boot ? "app controllers: explicit route-default actions plus directly declared public action_methods; inherited helpers excluded unless routed; dynamic :action routes not expanded" : "source-declared public controller methods only; inherited/generated/routes not enumerated",
          "source_sha256" => @index.files.merge(@templates.transform_values { _1.fetch("sha256") }).sort.to_h,
          "summary" => actions.group_by { _1.fetch("status") }.transform_values(&:size),
          "actions" => actions, "errors" => @index.errors,
          "limitations" => ["Advisory, not production admission; no purity or complete transitive gem call-graph proof.",
            "A source scan cannot prove no post-boot mutation; a clean boot is not an exercised seal-check.",
            "Small/large are source-shape rewrite candidates, not verified adoption effort.",
            "No profile means unknown estimated benefit, never zero; no generic removable-percent formula."]}
      end

      def action_report(controller, action)
        owner = controller.fetch("name")
        target = "#{owner}##{action}"
        seen, findings, calls = {}, [], []
        visit_method(owner, action, seen, findings, calls, view: false)
        # Helpers are a conservative name graph, not assumed-pure by their names.
        path = controller["controller_path"] || owner.sub(/Controller\z/, "").gsub("::", "/").gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
        template_files = Dir.glob("#{@root}/app/views/#{path}/#{action}.html*.erb")
        template_files += Dir.glob("#{@root}/app/views/layouts/application.html*.erb") unless template_files.empty?
        template_seen = {}
        template_files.each { visit_template(_1, owner, template_seen, seen, findings, calls) }
        callbacks = controller["callbacks"]
        if callbacks
          callbacks.each do |cb|
            if cb["kind"] == "around" || cb["filter_type"] != "method"
              findings << Subset.finding("SUB003", nil, nil, "#{cb['kind']} #{cb['filter_type']}: #{cb['filter']}")
            elsif @index.methods.key?([owner, cb["filter"]])
              visit_method(owner, cb["filter"], seen, findings, calls, view: false)
            end
          end
        end
        findings.uniq!
        status = if findings.any? { _1["rule"] == "SUB008" }
          "refused"
        elsif findings.any? { _1["effort"] == "large" }
          "large_rewrite_candidate"
        elsif !findings.empty?
          "small_rewrite_candidate"
        else
          "structural_candidate"
        end
        observed = read("observed.json")&.fetch("types", [])&.find { _1["module"] == owner && _1["name"] == action && !_1["singleton"] }
        files = seen.keys.map { @index.methods.fetch(_1).fetch("file") } + template_seen.keys
        ledger = read("ledger.json") || []
        sites = ledger.select { files.include?(_1["file"] || _1["target"]) }
        {"target" => target, "status" => status, "compliant" => false, "rules_broken" => findings,
          "classification" => status == "refused" ? "refused" : "structural_rewrite_candidate",
          "rewrite_size" => {"refused" => "unknown", "structural_candidate" => "none_detected", "small_rewrite_candidate" => "small", "large_rewrite_candidate" => "large"}.fetch(status),
          "pending_certificates" => ["SUB001: explicit opt-in and exercised post-readiness contract", "SUB008: complete helper/gem effects and framework source certification", *(callbacks ? [] : ["SUB003: booted callback inventory"]), *(@index.errors.empty? ? [] : ["SUB008: source parse errors"])],
          "source_methods" => seen.keys.map { _1.join("#") }.sort, "templates" => template_seen.keys.sort,
          "boot_callbacks" => callbacks, "model_references" => calls.uniq.select { @index.classes.dig(_1, "file")&.include?("/app/models/") }.sort,
          "benefit" => {"estimated_speedup_pct" => nil, "reason" => "No action-scoped completed-operation budget; reachability/sampled types are not removable work.",
            "observed_action_samples" => observed && observed.slice("calls", "saturated", "args", "returns"),
            "existing_lowering_sites" => sites},
          "prototype_admission" => "not_certified"}
      end

      def resolve(owner, name)
        visited = []
        while owner && !visited.include?(owner)
          return [owner, name] if @index.methods.key?([owner, name])
          visited << owner
          owner = @index.classes.dig(owner, "superclass")
        end
        nil
      end

      def visit_method(owner, name, seen, findings, calls, view:)
        key = resolve(owner, name)
        unless key
          findings << Subset.finding("SUB008", nil, nil, "No source definition for #{owner}##{name}")
          return
        end
        return if seen[key]
        seen[key] = true
        row = @index.methods.fetch(key)
        inspect_scan(row.fetch("scan"), row.fetch("file"), findings, calls, view: view)
        @index.seal_hints.fetch(row.fetch("file"), []).each do |hint|
          next unless %w[SEAL001 SEAL004 SEAL005 SEAL008 SEAL009].include?(hint["rule"]) &&
            (row.fetch("line")..row.fetch("node").location.end_line).cover?(hint["line"])
          findings << Subset.finding("SUB001", hint["file"], hint["line"], "#{hint['rule']}: #{hint['detail']}")
        end
        row.fetch("scan").calls.each do |call|
          next unless !call.receiver || Prism::SelfNode === call.receiver
          if resolve(owner, call.name.to_s)
            visit_method(owner, call.name.to_s, seen, findings, calls, view: view)
          elsif view
            helpers = @index.methods.keys.select { |candidate, method| candidate.end_with?("Helper") && method == call.name.to_s }
            helpers.each { |candidate, method| visit_method(candidate, method, seen, findings, calls, view: true) }
          end
        end
      end

      def inspect_scan(scan, file, findings, calls, view:)
        calls.concat(scan.constants)
        if view
          scan.writes.each { findings << Subset.finding("SUB005", file, _1.location.start_line, "Writes #{_1.name}") }
        end
        scan.calls.each do |call|
          args = call.arguments&.arguments || []
          rule = if %i[eval class_eval module_eval instance_eval define_method define_singleton_method method_missing].include?(call.name)
            "SUB002"
          elsif %i[send public_send __send__].include?(call.name) && !(Prism::SymbolNode === args.first || Prism::StringNode === args.first)
            "SUB002"
          elsif %i[find_by_sql execute exec_query constantize safe_constantize].include?(call.name)
            "SUB007"
          elsif %i[where joins from select order group].include?(call.name) && Prism::InterpolatedStringNode === args.first
            "SUB007"
          elsif %i[cache cache_if cache_unless render_stream render_to_string render_async].include?(call.name)
            "SUB006"
          end
          findings << Subset.finding(rule, file, call.location.start_line, call.location.slice.lines.first.strip) if rule
        end
      end

      def visit_template(file, owner, template_seen, methods, findings, calls)
        return if template_seen[file]
        template_seen[file] = true
        source = File.read(file)
        @templates[file] = {"sha256" => Digest::SHA256.hexdigest(source)}
        unless file.end_with?(".erb")
          findings << Subset.finding("SUB006", file, 1, "Non-ERB template")
          return
        end
        unless source.match?(/<%#\s*locals:\s*\(/)
          findings << Subset.finding("SUB004", file, 1, "No strict locals declaration")
        end
        # Rails' Erubi understands output blocks (<%= form_with ... do %>),
        # unlike stdlib ERB. Never evaluate generated code in the scanner.
        require "action_view"
        ruby = ActionView::Template::Handlers::ERB::Erubi.new(source, bufvar: "_subset_buffer").src
        parsed = Prism.parse("def __subset_template__\n#{ruby}\nend", version: PrismGrammar.version)
        unless parsed.success?
          findings << Subset.finding("SUB008", file, 1, "ERB Ruby parse: #{parsed.errors.first.message}")
          return
        end
        scan = Scan.new
        parsed.value.accept(scan)
        start = findings.size
        inspect_scan(scan, file, findings, calls, view: true)
        findings[start..].each { _1["line"] -= 1 if _1["line"] }
        scan.calls.each do |call|
          if call.name == :render
            args = call.arguments&.arguments || []
            literal = args.first
            if Prism::StringNode === literal
              path = literal.unescaped
              path = "#{File.dirname(file).delete_prefix("#{@root}/app/views/")}/#{path}" unless path.include?("/")
              base = "#{@root}/app/views/#{File.dirname(path)}/_#{File.basename(path)}"
              matches = Dir.glob("#{base}.html*.erb")
              findings << Subset.finding("SUB006", file, call.location.start_line - 1, "Missing HTML ERB partial: #{path}") if matches.empty?
              matches.each { visit_template(_1, owner, template_seen, methods, findings, calls) }
            else
              findings << Subset.finding("SUB006", file, call.location.start_line - 1, "Computed/options/collection render; declare finite graph (cache semantics retained)")
            end
          elsif !call.receiver || Prism::SelfNode === call.receiver
            @index.methods.keys.select { |candidate, method| candidate.end_with?("Helper") && method == call.name.to_s }.each do |candidate, method|
              visit_method(candidate, method, methods, findings, calls, view: true)
            end
          end
        end
      end

      def read(name)
        path = File.join(@root, ".lowrail", name)
        File.file?(path) ? JSON.parse(File.read(path)) : nil
      end
    end
  end
end

require_relative "../lib/harness"

# AP=fmt|rend, CAND=0|1. Every variant redefines the same methods with Rails main's bodies, so main and
# candidate pay the same redefinition cost; only the candidate's one change differs.
def lowrail_ap_patch(ap, cand)
  case ap
  when "fmt"
    ActionDispatch::Journey::Router::Utils::UriEncoder.class_eval do
      private def escape(component, pattern)
        return component unless component.match?(pattern)

        component.gsub(pattern) { |unsafe| percent_encode(unsafe) }.force_encoding(US_ASCII)
      end
    end
    ActionDispatch::Journey::Format.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      def initialize(parts)
        @parts      = #{cand ? "parts.chunk_while { |a, b| String === a && String === b }.map { |chunk| chunk.size > 1 ? chunk.join : chunk.first }" : "parts"}
        @children   = []
        @parameters = []

        @parts.each_with_index do |object, i|
          case object
          when ActionDispatch::Journey::Format
            @children << i
          when Parameter
            @parameters << i
          end
        end
      end

      def evaluate(hash)
        buffer = +""
        add_to(buffer, hash)
        buffer
      end

      protected def add_to(buffer, hash)
        @parameters.each do |index|
          return if hash[@parts[index].name].nil?
        end

        @parts.each do |part|
          case part
          when String
            buffer << part
          when ActionDispatch::Journey::Format
            part.add_to(buffer, hash)
          else
            buffer << part.escape(hash[part.name])
          end
        end
      end
    RUBY
    Rails.application.routes.routes.each do |route|
      route.instance_variable_set(:@path_formatter, route.path.build_formatter)
    end
  when "rend"
    all = ActionController::Renderers::RENDERERS.dup.freeze
    ActionController::Renderers.define_singleton_method(:lowrail_all) { all }
    ActionController::Renderers.module_eval do
      def _render_to_body_with_renderer(options)
        _all_renderers.each do |name|
          if options.key?(name)
            _process_options(options)
            method_name = ActionController::Renderers._render_with_renderer_method_name(name)
            return send(method_name, options.delete(name), options)
          end
        end
        nil
      end

      def _all_renderers
        _renderers
      end
    end
    ActionController::Renderers::All.module_eval <<~RUBY, __FILE__, __LINE__ + 1
      def _all_renderers
        #{cand ? "_renderers.empty? ? ActionController::Renderers.lowrail_all : _renderers + ActionController::Renderers.lowrail_all" : "_renderers + ActionController::Renderers.lowrail_all"}
      end
    RUBY
    [ActionController::Base, (ActionController::API if defined?(ActionController::API))].compact.each do |klass|
      klass._renderers = Set.new.freeze
    end
  end
end

def run_benchmark(_n, **, &block)
  lowrail_ap_patch(ENV.fetch("AP"), ENV["CAND"] == "1")
  if ENV["COUNT"]
    3.times(&block)
    counts = Hash.new(0)
    tp = TracePoint.new(:call) do |t|
      if t.method_id == :evaluate && t.defined_class == ActionDispatch::Journey::Format
        counts[:evaluate] += 1
      elsif t.method_id == :_render_to_body_with_renderer
        counts[:render_to_body] += 1
      end
    end
    n = 5
    tp.enable { n.times(&block) }
    puts "COUNTS #{counts.transform_values { _1.fdiv(n) }}"
    return
  end
  Integer(ENV.fetch("WARMUP_ITRS", "3")).times(&block)
  GC.start
  n = Integer(ENV.fetch("IR_ITRS", "1"))
  GC.disable
  [nil].cycle(1) { n.times(&block) }
  GC.enable
  puts "ir: measured #{n} iterations, ap=#{ENV["AP"]} cand=#{ENV["CAND"]}"
end

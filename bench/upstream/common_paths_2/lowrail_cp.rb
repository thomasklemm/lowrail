require_relative "../lib/harness"

# CP=ran|esc, CAND=0|1. Every variant redefines the method, so main and cand pay the same redefinition cost.
def lowrail_cp_patch(cp, cand)
  case cp
  when "ran"
    body = cand ? "name = super\n attribute_aliases[name] || name" : "attribute_aliases.fetch(super, &:itself)"
    ActiveModel::AttributeMethods::ClassMethods.module_eval <<~RUBY, __FILE__, __LINE__ + 1
      def resolve_attribute_name(name)
        #{body}
      end
    RUBY
  when "esc"
    ActionDispatch::Journey::Router::Utils::UriEncoder.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      SAFE_FRAGMENT = /\\A[\#{UNRESERVED}\#{SUB_DELIMS}:@\\/?]*\\z/
      SAFE_SEGMENT  = /\\A[\#{UNRESERVED}\#{SUB_DELIMS}:@]*\\z/
      SAFE_PATH     = /\\A[\#{UNRESERVED}\#{SUB_DELIMS}:@\\/]*\\z/
      def escape_fragment(fragment) = escape(fragment, FRAGMENT, SAFE_FRAGMENT)
      def escape_path(path) = escape(path, PATH, SAFE_PATH)
      def escape_segment(segment) = escape(segment, SEGMENT, SAFE_SEGMENT)

      private
        def escape(component, pattern, safe_pattern)
          #{cand ? "return component if component.match?(safe_pattern)" : "return component unless component.match?(pattern)"}

          component.gsub(pattern) { |unsafe| percent_encode(unsafe) }.force_encoding(US_ASCII)
        end
    RUBY
  end
end

def run_benchmark(_n, **, &block)
  lowrail_cp_patch(ENV.fetch("CP"), ENV["CAND"] == "1")
  Integer(ENV.fetch("WARMUP_ITRS", "3")).times(&block)
  GC.start
  n = Integer(ENV.fetch("IR_ITRS", "1"))
  GC.disable
  [nil].cycle(1) { n.times(&block) }
  GC.enable
  puts "ir: measured #{n} iterations, cp=#{ENV["CP"]} cand=#{ENV["CAND"]}"
end

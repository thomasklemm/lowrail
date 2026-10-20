# frozen_string_literal: true

module Lowrail
  # Separate from file ISeq delivery: ActionView compiles templates with
  # module_eval, so lowered template code is swapped in where Rails asks the
  # handler for the template's Ruby code. Only when the template source still
  # has the digest it was lowered from; otherwise Rails' own handler runs.
  module Templates
    class Handler
      def initialize(original, entry)
        @original = original
        @entry = entry
      end

      def call(template, source)
        require "digest" # lazily: setup must not load default gems (see lowrail.rb)
        # Endpoint generation retains the live handler invocation (including
        # config, extensions and effects). Only its exact compiled body may be
        # substituted. Existing source passes retain their delivery contract.
        if @entry.key?("original")
          code = @original.call(template, source)
          unless code == @entry.fetch("original")
            Lowrail.refuse("template handler body changed: #{template.identifier}; rebuild required")
            return code
          end
          unless Digest::SHA256.hexdigest(source.b) == @entry.fetch("source_sha256")
            Lowrail.refuse("template source digest mismatch: #{template.identifier}; rebuild required")
            return code
          end
          return @entry.fetch("code").dup
        end
        if Digest::SHA256.hexdigest(source.b) == @entry.fetch("source_sha256")
          Lowrail.debug("template #{template.identifier}: lowered")
          @entry.fetch("code").dup
        else
          Lowrail.refuse("template source digest mismatch: #{template.identifier}; using Rails' handler")
          @original.call(template, source)
        end
      end

      def method_missing(name, ...) = @original.public_send(name, ...)
      def respond_to_missing?(name, include_private = false) = @original.respond_to?(name, include_private)
    end

    module CompiledSource
      private

      def compiled_source
        entry = Lowrail::Templates.entries[identifier]
        return super unless entry

        original = @handler
        @handler = Handler.new(original, entry)
        begin
          super
        ensure
          @handler = original
        end
      end
    end

    class << self
      attr_reader :entries

      # Under RUBYOPT, setup runs before ActionView exists: wait for the
      # ActionView constant, then for ActionView::Template, and prepend then.
      def install(entries)
        @entries = entries
        if defined?(::ActionView) && !::ActionView.autoload?(:Template) && defined?(::ActionView::Template) then hook!
        elsif defined?(::ActionView) then ::ActionView.singleton_class.prepend(WatchTemplate)
        else Object.singleton_class.prepend(WatchActionView)
        end
      end

      def hook!
        ::ActionView::Template.prepend(CompiledSource) unless ::ActionView::Template < CompiledSource
      end
    end

    module WatchActionView
      private

      def const_added(name)
        super
        return unless name == :ActionView && equal?(Object)
        ::ActionView.singleton_class.prepend(WatchTemplate) unless ::ActionView.singleton_class < WatchTemplate
      end
    end

    module WatchTemplate
      private

      def const_added(name)
        super
        # Registering `autoload :Template` also fires const_added; only hook
        # once the class really exists, never trigger the autoload early.
        Lowrail::Templates.hook! if name == :Template && !autoload?(:Template)
      end
    end
  end

  # Escaping used by lowered helper code. Mirrors what the oracle verified at
  # build time: TagBuilder#tag_option for attribute values, content_tag_string
  # for element content.
  module Html
    def self.attr(value)
      v = ERB::Util.unwrapped_html_escape(value)
      v.include?('"') ? v.gsub('"', "&quot;") : v
    end

    def self.content(value)
      ERB::Util.unwrapped_html_escape(value)
    end
  end
end

# frozen_string_literal: true

# Attribution-only wrappers, installed BEFORE warmup/seal. They execute all
# original operations. Only counter collection changes, never app behavior.
require ENV.fetch("SEALED_RESIDUAL_EXTENSION")
require ENV.fetch("BENCH_CALLGRIND_EXTENSION")

module SealedResidual
  def self.wrap(holder, methods, scope)
    mod = Module.new
    methods.each do |name|
      raise "missing boundary #{holder}##{name}" unless holder.method_defined?(name) || holder.private_method_defined?(name)
      mod.define_method(name) do |*args, **kwargs, &block|
        SealedResidual.record(scope) { super(*args, **kwargs, &block) }
      end
      mod.send(:private, name) if holder.private_method_defined?(name)
    end
    holder.prepend(mod)
  end

  def self.install
    wrap(Article.singleton_class, %i[find new], 1)
    wrap(Comment.singleton_class, [:new], 1)
    wrap(ActiveRecord::Associations::Association, [:load_target], 1)
    wrap(ActiveRecord::Associations::CollectionAssociation, [:load_target], 1)
    wrap(ActiveRecord::AttributeMethods::Read, %i[_read_attribute read_attribute], 1)
    wrap(ActionDispatch::Session::CookieStore, %i[prepare_session commit_session], 2)
    wrap(ActionDispatch::Cookies::CookieJar, [:write], 2)
    wrap(ArticlesController, %i[verify_authenticity_token verify_same_origin_request form_authenticity_token], 2)
    wrap(ArticlesController.view_context_class, [:csrf_meta_tags], 2)
    wrap(ActiveSupport::Notifications::Fanout, %i[listening? build_handle], 3)
    wrap(ActiveSupport::Notifications::Fanout::Handle, %i[start finish], 3)
    scope = Integer(ENV.fetch("SEALED_RESIDUAL_SCOPE"))
    LowrailCallgrindBench.singleton_class.prepend(Module.new do
      define_method(:start) do |*args|
        super(*args)
        SealedResidual.start(scope)
      end
      define_method(:finish) do
        SealedResidual.finish
        super()
      end
    end)
  end
end
SealedResidual.install

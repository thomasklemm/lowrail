require "active_record"
require "action_view"
if ENV["GUARD_FIX"]
  ActionView::Helpers::Tags::Translator.class_eval do
    private
    def i18n_default
      if model
        key = model.model_name.i18n_key
        if Symbol === key && key.name == object_name
          ""
        else
          ["#{key}.#{method_and_value}".to_sym, ""]
        end
      else
        ""
      end
    end
  end
end
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title } }
class Post < ActiveRecord::Base; end
I18n.available_locales = [:en]
view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, Post.new(title: "Hello"), view, {})
def result(name)
  puts "#{name}: #{yield.inspect}"
rescue Exception => e
  puts "#{name}: #{e.class}: #{e.message}"
end

[:simple, :fallbacks, :chain, :memoize, :cache].each do |backend|
  klass = Class.new(I18n::Backend::Simple)
  klass.include(I18n::Backend::Fallbacks) if backend == :fallbacks
  klass.include(I18n::Backend::Memoize) if backend == :memoize
  if backend == :cache
    klass.include(I18n::Backend::Cache)
    I18n.cache_store = ActiveSupport::Cache::MemoryStore.new
  end
  I18n.backend = backend == :chain ? I18n::Backend::Chain.new(klass.new, klass.new) : klass.new
  target = backend == :chain ? I18n.backend.backends.last : I18n.backend
  translation = ->(_, **options) { options.fetch(:default).inspect }
  target.store_translations(:en, helpers: { label: { post: { title: translation } }, placeholder: { post: { title: translation } } })
  result("#{backend} default-aware label") { form.label(:title) }
  result("#{backend} default-aware placeholder") { form.text_field(:title, placeholder: true) }
end

I18n.backend = Class.new(I18n::Backend::Simple) { include I18n::Backend::Cache }.new
I18n.cache_store = ActiveSupport::Cache::MemoryStore.new
calls = 0
translation = ->(*) { "Label #{calls += 1}" }
I18n.backend.store_translations(:en, helpers: { label: { post: { title: translation } } })
empty_form = ActionView::Helpers::FormBuilder.new(:post, nil, view, {})
result("cache no-model label") { empty_form.label(:title) }
result("cache model label") { form.label(:title) }

[:first, :last].each do |location|
  a, b = I18n::Backend::Simple.new, I18n::Backend::Simple.new
  I18n.backend = I18n::Backend::Chain.new(a, b)
  target = location == :first ? a : b
  data = { post: { title: { short: "Short", long: "Long" } } }
  target.store_translations(:en, helpers: { label: data, placeholder: data })
  result("chain #{location}-backend hash label") { form.label(:title) }
  result("chain #{location}-backend hash label value") { form.label(:title, value: :short) }
  result("chain #{location}-backend hash placeholder") { form.text_field(:title, placeholder: true) }
end

class BareKey < BasicObject
  def to_s = "post"
end
name = Struct.new(:i18n_key).new(BareKey.new)
post = Post.new
post.define_singleton_method(:model_name) { name }
I18n.backend = I18n::Backend::Simple.new
I18n.backend.store_translations(:en, helpers: { label: { post: { title: "Label" } }, placeholder: { post: { title: "Placeholder" } } })
duck_form = ActionView::Helpers::FormBuilder.new(:post, post, view, {})
result("BasicObject key label") { duck_form.label(:title) }
result("BasicObject key placeholder") { duck_form.text_field(:title, placeholder: true) }

# Gem-side fix shape for shioyama/mobility#692, used to classify Spree's SP3 failures.
# Rails main's Relation#where calls _where! directly (c8490688d7), so mobility 1.3.2's
# QueryExtension#where! override no longer sees `where(permalink: ...)` on an i18n scope.
# Loaded after Mobility, this hooks _where! too; with it, Spree's api
# categories_controller_spec and products_controller_spec pass on Rails main.
module Mobility::Plugins::ActiveRecord::Query::QueryExtension
  def _where!(opts, rest = ::ActiveRecord::QueryMethods::FROZEN_EMPTY_ARRAY)
    Mobility::Plugins::ActiveRecord::Query::QueryExtension.const_get(:QueryBuilder).build(self, opts) do |untranslated_opts|
      untranslated_opts ? super(untranslated_opts, rest) : super
    end
  end
end

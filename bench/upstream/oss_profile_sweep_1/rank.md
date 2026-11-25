| # | Line | Method | Mean share | Apps ≥ 0.5% | redmine | solidus | forem | dawarich | osm | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` | `rszf` | 5.00% | 2 | 1.79% |  |  | 23.19% |  | `(num >> count) & ((1 << (ARCH_BITS - count)) - 1)` |
| 2 | `GEM/prosopite/lib/prosopite.rb:419` | `subscribe` | 1.65% | 1 |  |  |  |  | 8.24% | `query_caller = caller_locations` |
| 3 | `GEM/cancancan/lib/cancan/ability.rb:145` | `can` | 0.53% | 2 |  | 1.79% |  |  | 0.88% | `add_rule(Rule.new(true, action, subject, *attributes_and_conditions, &` |
| 4 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:184` | `to_wkt` | 0.51% | 1 |  |  |  | 2.56% | 0.01% | `content = wkt_content(standard_brackets).map { \|obj\| ",#{obj}" }.join` |
| 5 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:187` | `to_wkt` | 0.51% | 1 |  |  |  | 2.56% | 0.01% | `",AUTHORITY#{open}#{@authority.inspect},#{@authority_code.inspect}#{cl` |
| 6 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` | `tag_option` | 0.51% | 3 | 0.67% |  | 0.20% | 0.65% | 1.03% | `%(#{key}="#{value}")` |
| 7 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 0.42% | 2 | 0.71% | 0.00% | 0.19% | 0.41% | 0.80% | `ActiveSupport::SafeBuffer.new(self)` |
| 8 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 0.41% | 3 | 0.13% | 0.50% | 0.63% | 0.21% | 0.56% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 9 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 0.41% | 2 | 0.53% | 0.89% | 0.17% | 0.12% | 0.32% | `WhereClause.new(predicates \| other.predicates)` |
| 10 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 0.37% | 2 | 0.47% | 0.74% | 0.51% | 0.13% | 0.03% | `dispatch(:#{method}, ...)` |
| 11 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 0.37% | 2 | 0.58% | 0.67% | 0.26% | 0.16% | 0.18% | `Attribute.new(table, name)` |
| 12 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` | `get_oid_type` | 0.37% | 1 |  |  | 1.13% | 0.22% | 0.48% | `type_map.fetch(oid, fmod, sql_type) {` |
| 13 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 0.35% | 2 | 0.57% | 0.00% | 0.17% | 0.34% | 0.68% | `super` |
| 14 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` | `multiply` | 0.35% | 1 | 0.11% |  |  | 1.62% |  | `(0...e.get_length).each do \|j\|` |
| 15 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:193` | `to_wkt` | 0.34% | 1 |  |  |  | 1.70% | 0.00% | `@extensions.map { \|k, v\| ",EXTENSION#{open}#{k.inspect},#{v.inspect}#{` |
| 16 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:197` | `to_wkt` | 0.34% | 1 |  |  |  | 1.70% | 0.00% | `"#{wkt_typename}#{open}#{@name.inspect}#{content}#{extensions}#{author` |
| 17 | `GEM/cancancan/lib/cancan/rule.rb:137` | `wrap` | 0.33% | 2 |  | 1.10% |  |  | 0.56% | `[object]` |
| 18 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | `+` | 0.33% | 2 | 0.58% | 0.65% | 0.15% | 0.07% | 0.21% | `WhereClause.new(predicates + other.predicates)` |
| 19 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` | `extract_non_symbol_default!` | 0.28% | 1 | 0.06% | 0.03% | 0.27% |  | 1.06% | `defaults = [options[:default]].flatten` |
| 20 | `GEM/hashie/lib/hashie/mash.rb:374` | `convert_key` | 0.27% | 1 |  |  | 1.36% | 0.00% |  | `key.respond_to?(:to_sym) ? key.to_s : key` |
| 21 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` | `create` | 0.27% | 1 |  | 1.33% |  |  |  | `relation_class_for(klass).new(klass, *args, **kwargs)` |
| 22 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` | `expand_from_hash` | 0.26% | 1 | 0.36% | 0.59% | 0.13% | 0.07% | 0.18% | `attributes.flat_map do \|key, value\|` |
| 23 | `RAILS/activerecord/lib/active_record/core.rb:433` | `relation` | 0.26% | 1 | 0.29% | 0.79% | 0.09% |  | 0.12% | `relation = Relation.create(self)` |
| 24 | `RAILS/activerecord/lib/active_record/relation.rb:98` | `initialize_copy` | 0.25% | 1 | 0.41% | 0.51% | 0.16% | 0.05% | 0.13% | `@values = @values.dup` |
| 25 | `RAILS/activerecord/lib/arel.rb:56` | `sql` | 0.24% | 0 | 0.44% | 0.47% | 0.15% | 0.04% | 0.12% | `Arel::Nodes::SqlLiteral.new(sql_string, retryable: retryable)` |
| 26 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` | `cast_result` | 0.24% | 1 |  |  | 1.19% |  |  | `if result.fields.empty?` |
| 27 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:54` | `translate` | 0.24% | 1 | 0.32% | 0.07% | 0.20% |  | 0.59% | `fallback_options = options.merge(:fallback_in_progress => true, fallba` |
| 28 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` | `each` | 0.24% | 1 | 0.71% | 0.46% |  |  |  | `val = step` |
| 29 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` | `convert_dot_notation_to_hash` | 0.23% | 0 | 0.32% | 0.49% | 0.12% | 0.06% | 0.17% | `attributes.each_with_object({}) do \|(key, value), converted\|` |
| 30 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` | `references` | 0.23% | 0 | 0.32% | 0.49% | 0.12% | 0.06% | 0.17% | `attributes.each_with_object([]) do \|(key, value), result\|` |
| 31 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:60` | `translate` | 0.23% | 1 | 0.31% | 0.07% | 0.20% |  | 0.57% | `on_fallback(locale, fallback, key, options) if locale.to_s != fallback` |
| 32 | `GEM/posthog-rails/lib/posthog/rails/tracing_headers.rb:77` | `normalize_header_name` | 0.22% | 1 |  |  |  | 1.10% |  | `header_name.to_s.upcase.tr('-', '_')` |
| 33 | `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` | `build` | 0.22% | 1 |  |  |  | 1.08% |  | `path_str << DIR_PATH_COMMANDS[current_dir] << current_count.to_s if cu` |
| 34 | `GEM/cancancan/lib/cancan/ability/rules.rb:24` | `add_rule_to_index` | 0.21% | 1 |  | 0.63% |  |  | 0.44% | `subjects = rule.subjects.compact` |
| 35 | `GEM/cancancan/lib/cancan/rule.rb:31` | `initialize` | 0.21% | 1 |  | 0.62% |  |  | 0.44% | `@actions = wrap(action).map(&:to_sym)` |
| 36 | `GEM/cancancan/lib/cancan/rule.rb:121` | `parse_attributes_from_extra_args` | 0.21% | 1 |  | 0.62% |  |  | 0.44% | `[attributes, extra_args]` |
| 37 | `GEM/cancancan/lib/cancan/rule.rb:133` | `wrap` | 0.21% | 1 |  | 0.62% |  |  | 0.44% | `[]` |
| 38 | `GEM/hashie/lib/hashie/mash.rb:369` | `method_suffix` | 0.21% | 1 |  |  | 0.89% | 0.00% | 0.16% | `method_name = method_name.to_s` |
| 39 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 0.21% | 0 | 0.32% |  | 0.08% | 0.29% | 0.36% | `output = +""` |
| 40 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 0.21% | 0 | 0.18% | 0.31% | 0.19% | 0.08% | 0.28% | `result_lambda = -> { user_callback.call target, value }` |

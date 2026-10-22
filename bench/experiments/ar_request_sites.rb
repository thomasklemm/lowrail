# frozen_string_literal: true

# Bet F's ONE request-level pivot. External runtime overlay, never app/config
# edits, never required by lowrail/setup. Not a production method certificate.
require_relative "ar_callsite"

module ARRequestSites
  LOOKUP = Module.instance_method(:instance_method)
  PUBLIC = Module.instance_method(:public_method_defined?)
  BUCKET_TEMPLATE_SHA = "53e0883271b81f1883ad919c65122b67e23c2f4543fc058cf02fc181c5972c56"

  class << self
    attr_accessor :enabled, :counting
    attr_reader :counts, :sites

    def count(key)
      @counts[key] += 1 if counting
    end

    def install(config, arm)
      @counts, @sites = Hash.new(0), {}
      self.enabled, self.counting = arm == "on", ENV.key?("LOWRAIL_STATS")
      @holder = Lowrail::Native.method(:exact_class?)
      ActiveRecord::Relation.prepend(DirectQuery) unless ActiveRecord::Relation < DirectQuery
      case config.fetch("workload")
      when "campfire"
        owners = [Room, *Room.descendants]
        chain = ->(id) { Message.where(room_id: id).with_creator.with_attachment_details.with_boosts }
        @sites[:room_probe] = Site.new("room_probe", owners, :messages, Message, 1,
          %i[with_creator with_attachment_details with_boosts]) { chain.call(_1).where(id: nil).limit(1) }
        @sites[:room_page] = Site.new("room_page", owners, :messages, Message, 1,
          %i[with_creator with_attachment_details with_boosts ordered last_page]) { chain.call(_1).ordered.reverse_order.limit(40) }
        @room_method = RoomsController.instance_method(:find_messages)
        RoomsController.prepend(RoomController) unless RoomsController < RoomController
      when "fizzy"
        @sites[:bucket] = Site.new("bucket", [Bucket], :bubbles, Bubble, 2,
          %i[active published_or_drafted_by ordered_by_activity], extra_reflections: [[Bubble, :pop], [Bubble, :creator]]) do |bucket, user|
          # Stock's `creator: user` predicate uses the reflection's UTF-8 key,
          # not Symbol#to_s's US-ASCII name. Preserve even bind-name encoding.
          creator_key = Bubble.reflect_on_association(:creator).foreign_key
          Bubble.where(bucket_id: bucket).active.where(status: :published)
            .or(Bubble.where(bucket_id: bucket).active.where(status: :drafted, creator_key => user))
            .ordered_by_activity.limit(10)
        end
        @bucket_template = File.join(config.fetch("app"), "app/views/buckets/_bucket.html.erb")
        @user_class = User
        @user_methods = %i[id persisted?].map { [_1, @user_class.instance_method(_1)] }
        ActionView::Template::Handlers::ERB.prepend(BucketTemplate) unless ActionView::Template::Handlers::ERB < BucketTemplate
      else
        raise "only Campfire and Fizzy pivot sites"
      end
    end

    def bucket_rows(bucket, user)
      site = @sites.fetch(:bucket)
      if enabled && user.instance_of?(User) && user.persisted? && user.id.instance_of?(Integer) &&
          @holder.call(user, @user_class) &&
          @user_methods.all? { |name, method|
            PUBLIC.bind_call(@user_class, name) && LOOKUP.bind_call(@user_class, name) == method
          } && site.eligible?(bucket)
        site.load(bucket, [bucket.id, user.id]) do
          bucket.bubbles.active.published_or_drafted_by(user).ordered_by_activity.limit(10)
        end
      else
        count("bucket:fallback")
        bucket.bubbles.active.published_or_drafted_by(user).ordered_by_activity.limit(10)
      end
    end

    def room?(controller, room, params)
      enabled && controller.instance_of?(RoomsController) && params[:message_id].nil? &&
        controller.method(:find_messages).super_method&.unbind == @room_method &&
        @sites.fetch(:room_probe).eligible?(room) && @sites.fetch(:room_page).eligible?(room)
    end

    def room_rows(room)
      expected = -> { room.messages.with_creator.with_attachment_details.with_boosts }
      probe = @sites.fetch(:room_probe).load(room, [room.id]) { expected.call.where(id: nil).limit(1) }
      raise "nonempty null-primary-key probe" unless probe.empty?
      @sites.fetch(:room_page).load(room, [room.id]) { expected.call.ordered.reverse_order.limit(40) }.reverse!
    end

    def bucket_source(template, source)
      return source unless enabled && template.identifier == @bucket_template
      unless Digest::SHA256.hexdigest(source) == BUCKET_TEMPLATE_SHA
        count("bucket:source_mismatch")
        return source
      end
      from = "bucket.bubbles.active.published_or_drafted_by(Current.user).ordered_by_activity.limit(10)"
      raise "bucket callsite changed" unless source.scan(from).size == 1
      count("bucket:compiled_template")
      source.sub(from, "ARRequestSites.bucket_rows(bucket, Current.user)")
    end
  end

  class Site
    def initialize(name, owners, association, model, arity, methods, extra_reflections: [], &chain)
      @name, @owners, @association, @model = name, owners, association, model
      @holder = Lowrail::Native.method(:exact_class?)
      @template = chain.call(*Array.new(arity) { ActiveRecord::StatementCache::Substitute.new })
      raise "joined eager loads unsupported" if @template.eager_loading?
      model.with_connection do |connection|
        raise "SQLite prepared required" unless connection.instance_of?(ActiveRecord::ConnectionAdapters::SQLite3Adapter) && connection.prepared_statements
        @database_config = connection.pool.db_config.configuration_hash.deep_dup
        bind_connection(connection)
      end
      @model_facts = [model, *owners].uniq.map {
        [_1, _1.default_scopes.dup, _1.attribute_types, _1.current_role, _1.current_shard,
          _1.columns_hash, _1.arel_table, _1.table_name.dup]
      }
      # Check effective lookup AND visibility, including the model-specific
      # relation delegates. Hook notifications alone miss own-private changes.
      delegates = [ActiveRecord::Relation, ActiveRecord::AssociationRelation,
        ActiveRecord::Associations::CollectionProxy].map { model.send(:relation_delegate_class, _1) }
      builders = %i[where where! order limit includes preload or joins left_outer_joins reverse_order merge]
      @methods = ([[model.singleton_class, methods]] +
        delegates.map { [_1, methods + builders] } +
        [[ActiveRecord::QueryMethods::WhereChain, %i[missing]]]).flat_map do |holder, names|
        names.map { [holder, _1, LOOKUP.bind_call(holder, _1), PUBLIC.bind_call(holder, _1)] }
      end
      @readers = owners.to_h { |owner|
        [owner, [association, :id, :persisted?].map { [_1, owner.instance_method(_1)] }]
      }
      @reflections = (owners.map { [_1, association] } + extra_reflections).map do |klass, name|
        reflection = klass.reflect_on_association(name)
        [klass, name, reflection, reflection.options.deep_dup, reflection.scope,
          reflection.foreign_key.dup, reflection.active_record_primary_key.dup]
      end
    end

    def bind_connection(connection)
      @connection, @visitor = connection, connection.visitor
      @sql, binds, @preparable, @retryable = connection.send(:to_sql_and_binds, @template.arel)
      @bind_map = ActiveRecord::StatementCache::BindMap.new(binds)
      @process_id = Process.pid
    end

    def eligible?(owner)
      # CLASS_OF equality rejects even an empty existing eigenclass without
      # materializing one. Only then is ordinary-class lookup effective lookup;
      # retain both the body and public-visibility checks on every use.
      owner_class = @owners.find { @holder.call(owner, _1) }
      valid = owner_class && owner.persisted? && owner.id.instance_of?(Integer) &&
        @holder.call(owner, owner_class) &&
        @readers.fetch(owner_class).all? { |name, method|
          PUBLIC.bind_call(owner_class, name) && LOOKUP.bind_call(owner_class, name) == method
        } && @model_facts.all? { |model, defaults, types, role, shard, columns, table, table_name|
          model.default_scopes == defaults && model.attribute_types.equal?(types) &&
            model.current_scope.nil? && model.global_current_scope.nil? && model.current_role == role && model.current_shard == shard &&
            model.columns_hash.equal?(columns) && model.arel_table.equal?(table) && model.table_name == table_name
        } && @methods.all? { |holder, name, method, public_method|
          PUBLIC.bind_call(holder, name) == public_method && LOOKUP.bind_call(holder, name) == method
        } && @reflections.all? { |klass, name, reflection, options, scope, foreign_key, primary_key|
          klass.reflect_on_association(name).equal?(reflection) && reflection.options == options && reflection.scope.equal?(scope) &&
            reflection.foreign_key == foreign_key && reflection.active_record_primary_key == primary_key
        } && ActiveRecord.query_transformers.empty?
      if valid
        association = owner.association(@association)
        valid &&= !association.loaded? && association.instance_variable_get(:@association_scope).nil? && association.singleton_methods.empty?
        @model.with_connection do |connection|
          # The same path covers Puma's post-fork pools and Rails' fixture
          # connection replacement. Recompile only after every original fact
          # passes, for the same database config, adapter and prepared mode.
          forked = @process_id != Process.pid
          changed = forked || !connection.equal?(@connection) || !connection.visitor.equal?(@visitor)
          if valid && changed && connection.instance_of?(ActiveRecord::ConnectionAdapters::SQLite3Adapter) &&
              connection.prepared_statements && connection.pool.db_config.configuration_hash == @database_config
            bind_connection(connection)
            ARRequestSites.count("#{@name}:connection_bind")
            ARRequestSites.count("#{@name}:worker_bind") if forked
          end
          valid &&= connection.equal?(@connection) && connection.visitor.equal?(@visitor) && connection.prepared_statements
        end
      end
      ARRequestSites.count("#{@name}:fallback") unless valid
      valid
    rescue NameError
      ARRequestSites.count("#{@name}:fallback")
      false
    end

    def load(owner, values)
      binds = @bind_map.bind(values)
      raise "pivot unsupported bind" if binds.any? { _1.respond_to?(:unboundable?) && _1.unboundable? }
      if ARCallsite.shadow
        expected = Lowrail::ARShadow.relation(yield)
        actual = Lowrail::ARShadow.statement(@model, @connection, @sql, binds)
        raise "#{@name} SQL/bind mismatch: #{expected.inspect} != #{actual.inspect}" unless expected == actual
        ARRequestSites.count("#{@name}:shadow")
      end
      # Rails' AssociationRelation continuation sets inverse/strict-loading
      # through the normal instantiation block, before user callbacks.
      relation = ActiveRecord::AssociationRelation.create(@model, owner.association(@association))
      relation.instance_variable_set(:@values, @template.values)
      relation.instance_variable_set(:@ar_request_direct, [@sql, binds, @preparable, @retryable])
      ARRequestSites.count("#{@name}:hit")
      relation.to_a
    end
  end

  module DirectQuery
    private
    def exec_main_query(async: false)
      return super unless (plan = @ar_request_direct) && !async
      sql, binds, preparable, retryable = plan
      skip_query_cache_if_necessary do
        model.with_connection { model._query_by_sql(_1, sql, binds, preparable: preparable, allow_retry: retryable) }
      end
    end
  end

  module RoomController
    private
    def find_messages
      return super unless ARRequestSites.room?(self, @room, params)
      @messages = ARRequestSites.room_rows(@room)
    end
  end

  module BucketTemplate
    def call(template, source)
      super(template, ARRequestSites.bucket_source(template, source))
    end
  end
end

module NativeBench::Exploration
  class << self
    alias_method :install_final_relation, :install
    alias_method :final_relation_counts, :counts
    def install(config:, state:, arm:)
      install_final_relation(config: config.merge("ar_sql" => false, "ar_lean" => false), state: state, arm: arm)
      ARRequestSites.install(config, arm)
    end

    def counts
      final_relation_counts.merge("direct_sites" => ARRequestSites.counts.dup)
    end
  end
end

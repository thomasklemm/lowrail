# frozen_string_literal: true

require_relative "test_helper"

class TestCertificateTest < Minitest::Test
  include LowrailTest

  def test_cross_environment_opt_ins_and_unknown_workers_refuse
    rows = ruby_json(<<~'RUBY', setup: false, env: {"RUBYOPT" => "-I#{GEM_LIB}"})
      require "json"
      require "lowrail"
      require "lowrail/manifest"
      data = {"format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
        "compile_option" => "", "files" => {}, "units" => [{"id" => 0, "pass" => "sealed/link_to", "facts" => []}]}
      production = data.merge("tier" => "sealed-v1", "rails_env" => "production")
      verification = data.merge("tier" => "sealed-test-v1", "rails_env" => "test",
        "verification_test" => {"version" => 1, "mode" => "verification-only"})
      unsupported = %w[sealed/token_tag sealed/collection_render active_record/preload_plans].map do |pass|
        verification.merge("units" => [{"id" => 0, "pass" => pass, "facts" => []}])
      end
      ENV["LOWRAIL_SEALED"], ENV["LOWRAIL_VERIFY_TEST"] = "1", "1"
      puts JSON.generate([[production, "test", "1"], [verification, "production", "1"],
        [verification, "test", nil], [verification, "test", "2"],
        [verification, "test", "1"], [production, "production", "1"],
        *unsupported.map { [_1, "test", "1"] }].map do |artifact, env, workers|
        ENV["RAILS_ENV"], ENV["PARALLEL_WORKERS"] = env, workers
        Lowrail::Manifest.new(artifact, "/tmp").compatible?
      end)
    RUBY
    assert_equal [false, false, false, false, true, true, false, false, false], rows
  end

  def test_missing_real_initialization_never_authorizes_a_fact_free_unit
    result = ruby_json(<<~'RUBY', setup: false, env: {"RUBYOPT" => "-I#{GEM_LIB}"})
      require "json"
      require "tmpdir"
      require "lowrail"
      ENV.update("RAILS_ENV" => "test", "PARALLEL_WORKERS" => "1", "LOWRAIL" => "1",
        "LOWRAIL_SEALED" => "1", "LOWRAIL_VERIFY_TEST" => "1")
      data = {"format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
        "certification_jit" => Lowrail.jit_mode, "compile_option" => "", "files" => {},
        "tier" => "sealed-test-v1", "rails_env" => "test",
        "verification_test" => {"version" => 1, "mode" => "verification-only"},
        "units" => [{"id" => 0, "pass" => "active_record/instantiate", "facts" => [],
          "kind" => "runtime", "ar_instantiate" => {"model" => "NotLoaded"}}]}
      Dir.mktmpdir do |root|
        Dir.mkdir("#{root}/.lowrail")
        File.write("#{root}/.lowrail/manifest.json", JSON.generate(data))
        installed = Lowrail.setup(root: root)
        before = [Lowrail::TestCertificate.status, Lowrail.check(0), Lowrail::Stats.unit_hits]
        Lowrail::TestCertificate.test_initialized!
        puts JSON.generate([installed, before, Lowrail.check(0), Lowrail::TestCertificate.evidence])
      end
    RUBY
    assert_equal true, result[0]
    assert_equal ["pending", false, {}], result[1]
    assert_equal false, result[2]
    assert_equal "refused", result[3].fetch("state")
    refute_empty result[3].fetch("unit_refusals").fetch("0")
  end

  def test_source_set_includes_additions_removals_boot_and_test_initialization
    result = ruby_json(<<~'RUBY', setup: false, env: {"RUBYOPT" => "-I#{GEM_LIB}"})
      require "json"
      require "tmpdir"
      require "fileutils"
      require "lowrail"
      require "lowrail/manifest"
      require "lowrail/test_certificate"
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(["#{root}/config", "#{root}/test"])
        File.write("#{root}/config/boot.rb", "boot")
        File.write("#{root}/test/test_helper.rb", "workers")
        original = Lowrail::TestCertificate.sources(root)
        File.write("#{root}/config/new.rb", "added")
        added = Lowrail::TestCertificate.sources(root)
        File.unlink("#{root}/test/test_helper.rb")
        removed = Lowrail::TestCertificate.sources(root)
        puts JSON.generate([original.keys, original != added, added != removed])
      end
    RUBY
    assert_equal ["config/boot.rb", "test/test_helper.rb"], result[0]
    assert_equal [true, true], result.drop(1)
  end

  def test_natural_generation_releases_pending_once_and_live_resets_do_not_retire
    with_runtime_certificate do |dir, boot|
      result = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir))
        pending = Lowrail::TestCertificate.status
        query = -> { Widget.find_by_sql("SELECT * FROM widgets ORDER BY id").map { [_1.name, _1.status] } }
        before = query.call
        early_hits = Lowrail::Stats.unit_hits
        Lowrail::TestCertificate.test_initialized!
        3.times { query.call }
        subscription = ActiveSupport::Notifications.subscribe("instantiation.active_record") { |*| }
        ActiveSupport::CurrentAttributes.clear_all
        ActiveSupport::Notifications.unsubscribe(subscription)
        ActiveSupport::DescendantsTracker.reject!([Widget])
        Widget.class_eval { def unrelated_method = :still_live }
        after = query.call
        puts JSON.generate(pending: pending, early_hits: early_hits, before: before, after: after,
          stats: Lowrail::Stats.snapshot)
      RUBY
      assert_equal "pending", result.fetch("pending")
      assert_empty result.fetch("early_hits")
      assert_equal [["left", "draft"], ["right", "live"]], result.fetch("before")
      assert_equal result.fetch("before"), result.fetch("after")
      assert_equal 8, result.dig("stats", "unit_hits", "0")
      assert_empty result.dig("stats", "unit_deopts")
      assert_empty result.dig("stats", "unit_refusals")
    end
  end

  def test_active_parent_forks_original_child_with_no_inherited_authority_or_counters
    with_runtime_certificate do |dir, boot|
      result = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir))
        query = -> { Widget.find_by_sql("SELECT * FROM widgets ORDER BY id").map(&:name) }
        Lowrail::TestCertificate.test_initialized!
        query.call # Entire first row's natural generation is still original.
        rows = query.call
        receiver, builder = Object.new, Object.new
        Lowrail::G[7] = Lowrail::Stats::STATE[7] = true
        Lowrail::Stats::HITS[7], Lowrail::Stats::MISSES[7] = 17, 29
        Lowrail::K[7] = receiver
        Lowrail::V[7] = {receiver => true}.compare_by_identity
        Lowrail::Sealed::ACTIVE[0] = true
        Lowrail::Sealed::BUILDERS[builder] = true
        Thread.current[Lowrail::Sealed::REQUEST] = :seeded
        Lowrail::FormScaffold.instance_variable_set(:@active, true)
        Lowrail::FormScaffold.instance_variable_set(:@pending, true)
        Lowrail::FormScaffold.instance_variable_set(:@view_class, receiver)
        Lowrail::FormScaffold.instance_variable_set(:@admission, {state: "active"})
        parent = Lowrail::Stats.snapshot
        reader, writer = IO.pipe
        pid = fork do
          reader.close
          initial = Lowrail::Stats.snapshot
          # Exercise the same source/runtime predicates after seeded authority
          # was inherited. Merely zeroing counters would leave these fast.
          decisions = [Lowrail::G[7] || Lowrail.check(7),
            Lowrail::K[7].equal?(receiver) || Lowrail.ok?(7, receiver),
            !!Lowrail::Sealed.view?(Object.new), !!Lowrail::FormScaffold.admitted?]
          got = query.call
          Lowrail::TestCertificate.test_initialized!
          restored = query.call
          writer.write(JSON.generate(initial: initial, decisions: decisions, rows: got, restored: restored,
            active: Lowrail::Sealed::ACTIVE[0], builder: Lowrail::Sealed::BUILDERS.key?(builder),
            token: Thread.current[Lowrail::Sealed::REQUEST],
            form: Lowrail::FormScaffold.admission, after: Lowrail::Stats.snapshot))
          writer.close
          exit! 0
        end
        writer.close
        child = JSON.parse(reader.read)
        Process.wait(pid)
        raise "child failed" unless $?.success?
        puts JSON.generate(rows: rows, parent: parent, child: child, parent_rows: query.call,
          parent_after: Lowrail::Stats.snapshot)
      RUBY
      assert_equal ["left", "right"], result.fetch("rows")
      assert_equal result.fetch("rows"), result.fetch("parent_rows")
      assert_equal 2, result.dig("parent", "unit_hits", "0")
      assert_equal 4, result.dig("parent_after", "unit_hits", "0")
      child = result.fetch("child")
      assert_empty child.dig("initial", "unit_hits")
      assert_empty child.dig("initial", "unit_fallbacks")
      assert_equal [false, false, false, false], child.fetch("decisions")
      assert_equal result.fetch("rows"), child.fetch("rows")
      assert_equal child.fetch("rows"), child.fetch("restored")
      assert_equal false, child.fetch("active")
      assert_equal false, child.fetch("builder")
      assert_nil child.fetch("token")
      assert_equal "refused", child.dig("form", "state")
      assert_empty child.dig("after", "unit_hits")
      assert_equal 2, child.dig("after", "unit_fallbacks", "0")
      assert_equal 1, child.dig("after", "unit_deopts", "0")
      assert_equal ["verification_unexpected_pid_original_only"], child.dig("after", "unit_refusals", "0")
    end
  end

  def test_real_config_builder_bootsnap_and_method_mutations_retire_stickily
    with_runtime_certificate do |dir, boot|
      %w[config builder bootsnap method schema suite_mode].each do |mutation|
        result = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir).merge("MUTATION" => mutation))
          query = -> { Widget.find_by_sql("SELECT * FROM widgets ORDER BY id").map(&:name) }
          Lowrail::TestCertificate.test_initialized!
          rows = query.call
          query.call
          before = Lowrail::Stats.snapshot
          case ENV.fetch("MUTATION")
          when "config"
            old = Rails.application.config.eager_load
            Rails.application.config.eager_load = !old
            restore = -> { Rails.application.config.eager_load = old }
          when "builder"
            # Direct VM writes bypass instance_variable_set and AR reset hooks.
            old = Widget.instance_variable_get(:@attributes_builder)
            Widget.singleton_class.class_eval("def replace_cache(value); @attributes_builder = value; end")
            Widget.replace_cache(ActiveModel::AttributeSet::Builder.new(Widget.attribute_types))
            restore = -> { Widget.replace_cache(old) }
          when "bootsnap"
            old = Bootsnap::CompileCache::ISeq.instance_variable_get(:@default_compiler)
            Bootsnap::CompileCache::ISeq.default_compiler = old
            restore = -> { Bootsnap::CompileCache::ISeq.default_compiler = old }
          when "method"
            holder = ActiveRecord::ModelSchema::ClassMethods
            old = holder.instance_method(:attributes_builder)
            holder.define_method(:attributes_builder) { old.bind_call(self) }
            restore = -> { holder.define_method(:attributes_builder, old) }
          when "schema"
            Widget.reset_column_information
            restore = -> { Widget.first } # Natural rebuilding cannot revive.
          when "suite_mode"
            old = ENV["LOWRAIL_VERIFY_TEST_DIRECT"]
            ENV["LOWRAIL_VERIFY_TEST_DIRECT"] = "1"
            restore = -> { ENV["LOWRAIL_VERIFY_TEST_DIRECT"] = old }
          end
          after = query.call
          restore.call
          Lowrail::TestCertificate.test_initialized!
          restored = query.call
          puts JSON.generate(rows: rows, after: after, restored: restored, before: before,
            stats: Lowrail::Stats.snapshot)
        RUBY
        assert_equal ["left", "right"], result.fetch("rows"), mutation
        assert_equal result.fetch("rows"), result.fetch("after"), mutation
        assert_equal result.fetch("rows"), result.fetch("restored"), mutation
        assert_equal 2, result.dig("before", "unit_hits", "0"), mutation
        assert_equal 2, result.dig("stats", "unit_hits", "0"), mutation
        assert_operator result.dig("stats", "unit_fallbacks", "0"), :>=, 2, mutation
        assert_equal 1, result.dig("stats", "unit_deopts", "0"), mutation
        expected = {"config" => "verification_policy_mutation:eager_load=",
          "builder" => "verification_attributes_builder_replaced", "bootsnap" => "verification_bootsnap_policy_mutation",
          "method" => "dependent_method_or_ancestor_drift", "schema" => "dependent_state_mutation:reset_column_information",
          "suite_mode" => "verification_policy_or_source_drift"}
        assert_equal [expected.fetch(mutation)], result.dig("stats", "unit_refusals", "0"), mutation
      end
    end
  end

  def test_actual_parallel_policy_mismatch_refuses_despite_workers1
    with_runtime_certificate do |dir, boot|
      result = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir))
        old = Minitest.parallel_executor
        # No workers are started. The actual policy alone must refuse.
        Minitest.parallel_executor = ActiveSupport::Testing::ParallelizeExecutor.new(size: 2, with: :processes)
        Lowrail::TestCertificate.test_initialized!
        Minitest.parallel_executor = old
        Lowrail::TestCertificate.test_initialized!
        rows = Widget.order(:id).map(&:name)
        puts JSON.generate(rows: rows, stats: Lowrail::Stats.snapshot)
      RUBY
      assert_equal ["left", "right"], result.fetch("rows")
      assert_empty result.dig("stats", "unit_hits")
      assert_equal "refused", result.dig("stats", "verification_test", "state")
      assert_equal ["verification_parallel_policy_unknown"], result.dig("stats", "unit_refusals", "0")
    end
  end

  def test_render_certificate_keeps_live_token_continuations_and_collection_iteration
    with_render_certificate do |dir, boot|
      result = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir))
        original = view.method(:token_tag).super_method
        builder = view.instance_variable_get(:@tag_builder)
        Lowrail::Sealed::EPOCH[0] = 97 # Never borrowed or reset by verification.
        replacement = Class.new(ActionView::Helpers::TagHelper::TagBuilder) do
          def tag_options(*) = ' data-probe="late-builder"'
        end.new(view)
        token_id = ids.fetch("sealed/token_tag")
        tokens = [replacement, builder].map do |chosen|
          before = Lowrail::Stats.snapshot
          outputs = [false, true].map do |fast|
            view.instance_variable_set(:@tag_builder, builder)
            probe = {view: view, builder: chosen, generated: 0, converted: 0}
            Thread.current[:render_probe] = probe
            output = fast ? view.send(:token_tag, nil, form_options: options) : original.call(nil, form_options: options)
            Thread.current[:render_probe] = nil
            [output, probe[:generated], probe[:converted]]
          end
          after = Lowrail::Stats.snapshot
          {outputs: outputs, hits: after.fetch("unit_hits").fetch(token_id, 0) - before.fetch("unit_hits").fetch(token_id, 0),
            fallbacks: after.fetch("unit_fallbacks").fetch(token_id, 0) - before.fetch("unit_fallbacks").fetch(token_id, 0)}
        end
        rendered = [false, true].map do |fast|
          events.clear
          output = render_collection.call(fast)
          {output: output, events: events.dup}
        end
        layout = Object.new
        layout.define_singleton_method(:render) { |*args, &block| "wrapped:#{block.call}" }
        layouts = [false, true].map { render_collection.call(_1, layout) }
        nested = nil
        during_render = -> { during_render = nil; nested = render_collection.call(true) }
        reentrant = [render_collection.call(true), nested]
        errors = [false, true].map do |fast|
          events.clear
          during_render = -> { raise ArgumentError, "live template failure" }
          begin
            render_collection.call(fast)
          rescue ArgumentError => error
            [error.message, events.dup]
          ensure
            during_render = nil
          end
        end
        # Unrelated live rows/subscribers and a new unknown view are not a
        # mutation of the accepted holder. A foreign input stays local.
        subscriber = ActiveSupport::Notifications.subscribe("render_partial.action_view") { |*| }
        Article.first.update!(title: "live data")
        ActiveSupport::Notifications.unsubscribe(subscriber)
        foreign = ActionView::Base.empty
        foreign_output = foreign.send(:token_tag, false, form_options: options)
        render_collection.call(true)
        result = {tokens: tokens, rendered: rendered, layouts: layouts, reentrant: reentrant, errors: errors, foreign: foreign_output,
          private_generation: view.class.private_method_defined?(:form_authenticity_token),
          production_epoch: Lowrail::Sealed::EPOCH[0],
          admitted: [Lowrail::TokenTag.admitted?, Lowrail::CollectionRender.admitted?], stats: Lowrail::Stats.snapshot}
      RUBY
      foreign, restored = result.fetch("tokens")
      assert_equal '<input data-probe="late-builder" />', foreign.fetch("outputs").first.first
      [foreign, restored].each do |record|
        assert_equal record.fetch("outputs").first, record.fetch("outputs").last
        assert_equal [1, 1], record.fetch("outputs").first.drop(1), "live generation and conversion once, never replayed"
      end
      assert_equal [0, 1], foreign.values_at("hits", "fallbacks")
      assert_equal [1, 0], restored.values_at("hits", "fallbacks")
      assert_equal result.fetch("rendered").first, result.fetch("rendered").last
      assert_equal ["left/0/2", "right/1/2"], result.dig("rendered", 0, "output")
      assert_equal ["size", "iterator", "left", "right"], result.dig("rendered", 0, "events")
      assert_equal [["wrapped:left/0/2", "wrapped:right/1/2"]] * 2, result.fetch("layouts")
      assert_equal [["left/0/2", "right/1/2"]] * 2, result.fetch("reentrant")
      assert_equal [["live template failure", ["size", "iterator", "left"]]] * 2, result.fetch("errors")
      assert_equal "", result.fetch("foreign")
      assert_equal true, result.fetch("private_generation"), "private before the first original-operation witness"
      assert_equal 97, result.fetch("production_epoch")
      assert_equal [true, true], result.fetch("admitted")
      assert_empty result.dig("stats", "unit_deopts")
    end
  end

  def test_render_name_and_tag_dispatch_bypass_existing_view_reflection
    with_render_certificate do |dir, boot|
      # Isolate the reflective-dispatch regression from the private-generator
      # case. All setup precedes the first original-operation witness.
      boot = boot.dup
      changed = boot.sub!("foreign_view.class.send(:private, :form_authenticity_token)", <<~'RUBY')
        names = %i[protect_against_forgery? form_authenticity_token request_forgery_protection_token]
        mode = ENV.fetch("RENDER_HELPER_MODE")
        if mode == "method_missing"
          # A missing protection method is an existing named admission
          # refusal; generation and name lookup remain live and may be missing.
          missing = names.drop(1)
          originals = missing.to_h { [_1, foreign_view.class.instance_method(_1)] }
          foreign_view.class.define_method(:respond_to_missing?) do |name, include_private = false|
            originals.key?(name) || super(name, include_private)
          end
          foreign_view.class.define_method(:method_missing) do |name, *args, **keywords, &block|
            if (original = originals[name])
              Thread.current[:render_probe]&.fetch(:missing_calls)&.push(name.to_s)
              original.bind_call(self, *args, **keywords, &block)
            else
              super(name, *args, **keywords, &block)
            end
          end
          missing.each { foreign_view.class.send(:undef_method, _1) }
        else
          foreign_view.class.send(mode, *names)
        end
        module ExistingViewReflection
          %i[send __send__ public_send method].each do |reflection|
            define_method(reflection) do |name, *args, **keywords, &block|
              probe = Thread.current[:render_probe]
              if probe && %i[protect_against_forgery? form_authenticity_token request_forgery_protection_token tag tag_builder].include?(name)
                probe[:reflective_calls] << reflection.to_s
                "wrong-#{name}-from-#{reflection}"
              else
                super(name, *args, **keywords, &block)
              end
            end
          end

          def instance_exec(*)
            raise "unexpected view instance_exec dispatch" if Thread.current[:render_probe]
            super
          end
        end
        foreign_view.class.prepend(ExistingViewReflection)
      RUBY
      raise "view setup not found" unless changed
      %w[public protected method_missing].each do |mode|
        result = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir).merge("RENDER_HELPER_MODE" => mode))
          original = view.method(:token_tag).super_method
          builder = view.instance_variable_get(:@tag_builder)
          foreign = Class.new(ActionView::Helpers::TagHelper::TagBuilder) do
            def tag_options(*) = ' data-probe="late-builder"'
          end.new(view)
          token_id = ids.fetch("sealed/token_tag")
          records = [builder, foreign].map do |chosen|
            before = Lowrail::Stats.snapshot
            pair = [false, true].map do |fast|
              view.instance_variable_set(:@tag_builder, builder)
              probe = {view: view, builder: chosen, generated: 0, converted: 0, reflective_calls: [], missing_calls: []}
              Thread.current[:render_probe] = probe
              output = fast ? view.send(:token_tag, nil, form_options: options) : original.call(nil, form_options: options)
              Thread.current[:render_probe] = nil
              [output, probe[:generated], probe[:converted], probe[:reflective_calls], probe[:missing_calls]]
            end
            after = Lowrail::Stats.snapshot
            {pair: pair, hits: after.fetch("unit_hits").fetch(token_id, 0) - before.fetch("unit_hits").fetch(token_id, 0),
              fallbacks: after.fetch("unit_fallbacks").fetch(token_id, 0) - before.fetch("unit_fallbacks").fetch(token_id, 0)}
          end
          result = {public_generator: view.class.public_method_defined?(:form_authenticity_token),
            protected_generator: view.class.protected_method_defined?(:form_authenticity_token), records: records,
            admitted: [Lowrail::TokenTag.admitted?, Lowrail::CollectionRender.admitted?], stats: Lowrail::Stats.snapshot}
        RUBY
        assert_equal mode == "public", result.fetch("public_generator")
        assert_equal mode == "protected", result.fetch("protected_generator")
        stock, continuation = result.fetch("records")
        result.fetch("records").each do |record|
          assert_equal record.fetch("pair").first, record.fetch("pair").last, mode
          assert_equal [1, 1, []], record.fetch("pair").last.values_at(1, 2, 3), "implicit calls never dispatch through view reflection"
          expected_missing = mode == "method_missing" ? %w[form_authenticity_token request_forgery_protection_token] : []
          assert_equal expected_missing, record.fetch("pair").last.last
        end
        assert_equal '<input data-probe="late-builder" />', continuation.fetch("pair").last.first
        assert_equal [1, 0], stock.values_at("hits", "fallbacks")
        assert_equal [0, 1], continuation.values_at("hits", "fallbacks")
        assert_equal [true, true], result.fetch("admitted")
        assert_empty result.dig("stats", "unit_deopts")
      end
    end
  end

  def test_render_missing_or_mismatched_view_context_certificate_stays_original
    with_render_certificate do |dir, boot|
      path = File.join(dir, ".lowrail/manifest.json")
      original = File.read(path)
      boot = boot.dup
      changed = boot.sub!('raise "not naturally admitted" unless Lowrail::TokenTag.admitted? && Lowrail::CollectionRender.admitted?',
        'raise "invalid dispatch certificate admitted" if Lowrail::TokenTag.admitted? || Lowrail::CollectionRender.admitted?')
      raise "admission assertion not found" unless changed
      %w[missing mismatched].each do |mode|
        manifest = JSON.parse(original)
        manifest.fetch("units").each do |unit|
          next unless (data = unit["verification_render"])
          mode == "missing" ? data.delete("view_context") : data["view_context"] = {"owner" => "NotBasicObject"}
        end
        File.write(path, JSON.generate(manifest))
        result = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir))
          original = view.method(:token_tag).super_method
          tokens = [false, true].map do |fast|
            probe = {view: view, builder: view.instance_variable_get(:@tag_builder), generated: 0, converted: 0}
            Thread.current[:render_probe] = probe
            output = fast ? view.send(:token_tag, nil, form_options: options) : original.call(nil, form_options: options)
            Thread.current[:render_probe] = nil
            [output, probe[:generated], probe[:converted]]
          end
          result = {tokens: tokens, collections: [false, true].map { render_collection.call(_1) },
            render_ids: %w[sealed/token_tag sealed/collection_render].map { ids.fetch(_1) }, stats: Lowrail::Stats.snapshot}
        RUBY
        assert_equal result.fetch("tokens").first, result.fetch("tokens").last, mode
        assert_equal [1, 1], result.fetch("tokens").last.drop(1)
        assert_equal result.fetch("collections").first, result.fetch("collections").last, mode
        reason = mode == "missing" ? "verification_render_observation_unknown" : "verification_render_view_context_dispatch_changed;_rebuild"
        result.fetch("render_ids").each do |id|
          assert_equal 0, result.dig("stats", "unit_hits").fetch(id, 0)
          assert_equal [reason], result.dig("stats", "unit_refusals", id)
        end
      end
    end
  end

  def test_render_mutation_and_fork_authority_are_sticky_and_unit_local
    with_render_certificate do |dir, boot|
      %w[method continuation table lexical size dispatch tier opt_in fork].each do |mutation|
        result = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir).merge("MUTATION" => mutation))
          before = Lowrail::Stats.snapshot
          case ENV.fetch("MUTATION")
          when "method"
            holder = ActionView::Helpers::TagHelper::TagBuilder
            saved = holder.instance_method(:tag_option)
            holder.define_method(:tag_option) { |*args| saved.bind_call(self, *args) }
            restore = -> { holder.define_method(:tag_option, saved); holder.send(:private, :tag_option) }
          when "continuation"
            holder = ActionView::Helpers::TagHelper::TagBuilder
            saved = holder.instance_method(:tag_options)
            probe = {view: view, builder: view.instance_variable_get(:@tag_builder), generated: 0, converted: 0,
              mutate: -> { holder.define_method(:tag_options) { |*| ' data-probe="mutated"' } }}
            Thread.current[:render_probe] = probe
            fast_output = view.send(:token_tag, nil, form_options: options)
            generation = probe[:generated]
            probe[:mutate] = nil
            original_output = view.method(:token_tag).super_method.call(nil, form_options: options)
            token_pair = [original_output, fast_output]
            Thread.current[:render_probe] = nil
            restore = -> { holder.define_method(:tag_options, saved) }
          when "table"
            holder = ActionView::Helpers::TagHelper
            saved = holder::TAG_TYPES
            holder.send(:remove_const, :TAG_TYPES)
            holder.const_set(:TAG_TYPES, saved.merge(name: :boolean).freeze)
            restore = -> { holder.send(:remove_const, :TAG_TYPES); holder.const_set(:TAG_TYPES, saved) }
          when "lexical", "size"
            holder = ActionView::CollectionRenderer
            mutate = -> do
              during_size = nil
              holder.const_set(:PartialIteration, Class.new(ActionView::PartialIteration) do
                def index = super + 7
              end)
            end
            if ENV.fetch("MUTATION") == "size"
              during_size = mutate
              size_output = render_collection.call(true)
            else
              mutate.call
            end
            restore = -> { holder.send(:remove_const, :PartialIteration) }
          when "tier"
            ENV["RAILS_ENV"] = "production"
            restore = -> { ENV["RAILS_ENV"] = "test" }
          when "dispatch"
            holder = Lowrail::Sealed
            saved = holder::VIEW_CONTEXT
            holder.send(:remove_const, :VIEW_CONTEXT)
            holder.const_set(:VIEW_CONTEXT, Kernel.instance_method(:itself))
            restore = -> { holder.send(:remove_const, :VIEW_CONTEXT); holder.const_set(:VIEW_CONTEXT, saved) }
          when "opt_in"
            ENV["LOWRAIL_VERIFY_TEST"] = "0"
            restore = -> { ENV["LOWRAIL_VERIFY_TEST"] = "1" }
          when "fork"
            reader, writer = IO.pipe
            pid = fork do
              reader.close
              initial = Lowrail::Stats.snapshot
              outputs = [view.send(:token_tag, nil, form_options: options), render_collection.call(true)]
              Lowrail::TestCertificate.test_initialized!
              writer.write(JSON.generate(initial: initial, outputs: outputs, stats: Lowrail::Stats.snapshot,
                admitted: [Lowrail::TokenTag.admitted?, Lowrail::CollectionRender.admitted?]))
              writer.close
              exit! 0
            end
            writer.close
            child = JSON.parse(reader.read)
            Process.wait(pid)
            raise "child failed" unless $?.success?
            result = {before: before, child: child,
              admitted: [Lowrail::TokenTag.admitted?, Lowrail::CollectionRender.admitted?]}
            exit
          end
          # Both paths still produce the original result after a mutation.
          original = view.method(:token_tag).super_method
          if %w[method table].include?(ENV.fetch("MUTATION"))
            Thread.current[:render_probe] = {view: view, builder: view.instance_variable_get(:@tag_builder), generated: 0, converted: 0}
          end
          token_pair ||= [original.call(nil, form_options: options), view.send(:token_tag, nil, form_options: options)]
          Thread.current[:render_probe] = nil
          collection_pair = [render_collection.call(false), render_collection.call(true)]
          restore.call
          Lowrail::TestCertificate.test_initialized!
          view.send(:token_tag, nil, form_options: options)
          render_collection.call(true)
          result = {before: before, token: token_pair, collection: collection_pair,
            generation: generation, size_output: size_output,
            admitted: [Lowrail::TokenTag.admitted?, Lowrail::CollectionRender.admitted?], stats: Lowrail::Stats.snapshot}
        RUBY
        if mutation == "fork"
          assert_equal [true, true], result.fetch("admitted")
          child = result.fetch("child")
          assert_empty child.dig("initial", "unit_hits")
          assert_empty child.dig("initial", "unit_fallbacks")
          assert_equal [false, false], child.fetch("admitted")
          assert_equal ["", ["left/0/2", "right/1/2"]], child.fetch("outputs")
          assert_empty child.dig("stats", "unit_hits")
          %w[4 5].each do |id|
            assert_equal 1, child.dig("stats", "unit_deopts", id)
            assert_equal ["verification_unexpected_pid_original_only"], child.dig("stats", "unit_refusals", id)
          end
        else
          assert_equal result.fetch("token").first, result.fetch("token").last, mutation
          assert_equal result.fetch("collection").first, result.fetch("collection").last, mutation
          if mutation == "continuation"
            assert_equal '<input data-probe="mutated" />', result.fetch("token").last
            assert_equal 1, result.fetch("generation"), "mutation must not replay live generation"
          elsif mutation == "size"
            assert_equal ["left/0/2", "right/1/2"], result.fetch("size_output"), "lookup precedes the live size callback"
            assert_equal ["left/7/2", "right/8/2"], result.fetch("collection").last
          end
          expected = %w[dispatch tier opt_in].include?(mutation) ? [false, false] : %w[lexical size].include?(mutation) ? [true, false] : [false, true]
          assert_equal expected, result.fetch("admitted"), mutation
          expected.each_with_index do |active, index|
            id = (4 + index).to_s
            assert_equal(active ? 0 : 1, result.dig("stats", "unit_deopts").fetch(id, 0), mutation)
            next if active
            prior = result.dig("before", "unit_hits", id)
            prior += 1 if mutation == "size" && index == 1
            assert_equal prior, result.dig("stats", "unit_hits", id), mutation
            refute_empty result.dig("stats", "unit_refusals", id), mutation
          end
        end
      end
    end
  end

  private

  def certificate_env(dir)
    {"LOWRAIL" => "1", "RAILS_ENV" => "test", "PARALLEL_WORKERS" => "1", "CI" => nil,
      "LOWRAIL_SEALED" => "1", "LOWRAIL_VERIFY_TEST" => "1", "LOWRAIL_SQL_TRACE" => "0",
      "LOWRAIL_DIR" => "#{dir}/.lowrail", "LOWRAIL_ROOT" => dir}
  end

  def with_runtime_certificate
    missing_prerequisite "Rails, sqlite3 or bcrypt not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      environment = LowrailTest::RAILS_APP.fetch("config/environment.rb").sub("config.eager_load = false",
        "config.eager_load = false\n    config.cache_store = :null_store\n    config.yjit = false")
        .sub("create_table(:widgets)", "create_table(:widgets, force: true)")
      LowrailTest.write_rails_app(dir, "config/environment.rb" => environment,
        "config/database.yml" => "test:\n  adapter: sqlite3\n  database: tmp/verification.sqlite3\n  pool: 1\n",
        "config/boot.rb" => <<~'RUBY', "test/test_helper.rb" => <<~'RUBY')
          require "bootsnap"
          Bootsnap.setup(cache_dir: File.join(Dir.pwd, "tmp/cache"), development_mode: false,
            load_path_cache: true, compile_cache_iseq: true, compile_cache_yaml: true, compile_cache_json: true)
        RUBY
          require_relative "../config/environment"
          require "active_support/test_case"
          ActiveSupport::TestCase.parallelize(workers: 1)
          Minitest.parallel_executor.start
          ActiveRecord::Base.connection.execute("INSERT INTO widgets (id, name, status) VALUES (1, 'left', 0), (2, 'right', 1)")
        RUBY
      boot = "require 'json'; require './config/boot'; require './test/test_helper'\n"
      built = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir).merge("LOWRAIL" => "0"))
        require "lowrail/manifest"
        Widget.first # Only natural app loading can supply build discovery.
        certificate = Lowrail::TestCertificate.certificate(Dir.pwd)
        require "lowrail/ar_instantiate_build"
        units = Lowrail::ARInstantiateBuild.build(verification_test: true).fetch(:units)
        units.each_with_index { |unit, id| unit["id"] = id }
        data = {format: Lowrail::FORMAT, ruby_description: RUBY_DESCRIPTION, certification_jit: Lowrail.jit_mode,
          compile_option: Lowrail::Manifest.compile_option_fingerprint, files: {}, units: units,
          tier: "sealed-test-v1", rails_env: "test", verification_test: certificate}
        FileUtils.mkdir_p(".lowrail")
        File.write(".lowrail/manifest.json", JSON.generate(data))
        puts JSON.generate(units.map { _1.dig("ar_instantiate", "model") })
      RUBY
      assert_equal ["Widget"], built
      yield dir, boot
    end
  end

  def with_render_certificate
    missing_prerequisite "render certificate requires Ruby 4.0.7" unless RUBY_VERSION == "4.0.7"
    corpus = File.join(CORPUS_ROOT, "real-blog-r4")
    missing_prerequisite "no #{corpus} (see script/corpus)" unless File.file?(File.join(corpus, "test/test_helper.rb"))
    realpath_tmpdir do |dir|
      (Dir.children(corpus) - %w[.git .lowrail tmp log node_modules storage]).each { FileUtils.cp_r(File.join(corpus, _1), dir) }
      FileUtils.mkdir_p(File.join(dir, "storage"))
      out, err, status = Open3.capture3(CLEAN_ENV.merge(certificate_env(dir)).merge("LOWRAIL" => "0"),
        lowrail_cli, "build", dir, "--sealed", "--verify-test", "--env", "test", "--jit", "interpreter", chdir: dir)
      assert status.success?, "#{out}\n#{err}"
      FileUtils.cp_r(File.join(dir, ".lowrail/verification-test/.", "."), File.join(dir, ".lowrail"))
      manifest = JSON.parse(File.read(File.join(dir, ".lowrail/manifest.json")))
      assert_equal %w[active_record/instantiate active_record/instantiate sealed/link_to sealed/form_scaffold
        sealed/token_tag sealed/collection_render], manifest.fetch("units").map { _1.fetch("pass") }
      boot = <<~'RUBY'
        require "json"
        result = nil
        at_exit { puts JSON.generate(result) if result }
        require "./config/boot"
        require "./config/application"
        module LiveTokenProbe
          def protect_against_forgery?
            Thread.current[:render_probe] ? true : super
          end
          def form_authenticity_token(**options)
            probe = Thread.current[:render_probe]
            return super unless probe
            probe[:generated] += 1
            probe[:view].instance_variable_set(:@tag_builder, probe[:builder])
            probe[:mutate]&.call
            'value<&" Ω'
          end
          def request_forgery_protection_token
            probe = Thread.current[:render_probe]
            return super unless probe
            name = Object.new
            name.define_singleton_method(:to_s) { probe[:converted] += 1; 'name<&" Ω' }
            name
          end
        end
        ActiveSupport.on_load(:action_controller) { prepend LiveTokenProbe }
        require "./test/test_helper"
        Minitest.parallel_executor.start
        Lowrail::TestCertificate.test_initialized!
        raise "authority before original operation" if Lowrail::TokenTag.admitted? || Lowrail::CollectionRender.admitted?
        ActiveRecord::FixtureSet.create_fixtures(Rails.root.join("test/fixtures"), %w[articles comments])
        # Completing an inherited body on a foreign renderer cannot witness
        # the canonical renderer. The later real request must supply that.
        foreign_renderer = Class.new(ActionView::CollectionRenderer).allocate
        foreign_renderer.instance_variable_set(:@locals, {})
        empty = Object.new
        empty.define_singleton_method(:size) { 0 }
        empty.define_singleton_method(:each_with_info) { [] }
        foreign_view = ArticlesController.new.view_context
        # Stock token_tag dispatches implicitly, including to a private
        # generator. Set visibility before either unit's first witness, not
        # as a post-admission mutation that would already retire authority.
        foreign_view.class.send(:private, :form_authenticity_token)
        foreign_renderer.send(:collection_with_template, foreign_view, Object.new, nil, empty)
        raise "foreign renderer authorized canonical context" if Lowrail::CollectionRender.admitted?
        require "rack/mock"
        view = nil
        trace = TracePoint.new(:call) { |event| view = event.self }
        trace.enable(target: Lowrail::TokenTag::Variant.instance_method(:token_tag))
        request = Rack::MockRequest.new(Rails.application)
        2.times { raise "request failed" unless request.get("/articles/#{Article.first.id}", "HTTP_HOST" => "www.example.com").status == 200 }
        trace.disable
        raise "not naturally admitted" unless Lowrail::TokenTag.admitted? && Lowrail::CollectionRender.admitted?
        ids = Lowrail.manifest.units.to_h { [_1.fetch("pass"), _1.fetch("id").to_s] }
        options = {action: "/articles/1/comments", method: "post"}
        events = []
        during_size = during_render = nil
        iterator = Object.new
        iterator.define_singleton_method(:size) { events << "size"; during_size&.call; 2 }
        iterator.define_singleton_method(:each_with_info) do
          events << "iterator"
          [["left", ["shared", :item, :item_counter, :item_iteration]], ["right", ["shared", :item, :item_counter, :item_iteration]]]
        end
        template = Object.new
        template.define_singleton_method(:render) do |_view, locals, implicit_locals:|
          events << locals.fetch(:item)
          during_render&.call
          "#{locals.fetch(:item)}/#{locals.fetch(implicit_locals.first)}/#{locals.fetch(implicit_locals.last).size}"
        end
        render_collection = ->(fast, layout = nil) do
          renderer = ActionView::CollectionRenderer.allocate
          renderer.instance_variable_set(:@locals, {})
          method = renderer.method(:collection_with_template)
          method = method.super_method unless fast
          method.call(view, template, layout, iterator).map(&:body)
        end
      RUBY
      yield dir, boot
    end
  end
end

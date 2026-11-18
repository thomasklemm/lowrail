# frozen_string_literal: true

require "json"

module Lowrail
  # lowrail-profile compare BASE.json HEAD.json: warm objects per request (and
  # per job, mail and Action Cable action) by line outside the app and by
  # action, head minus base. A change counts as a regression when it is larger
  # than the noise floor: for a line, the bigger of the two reports' own
  # run-to-run spread (largest minus smallest run) and --min objects; for an
  # action, twice that spread, 0.1% of its objects and 20 times --min, because
  # parallel test workers split an action's requests differently from run to
  # run (A/A on Campfire: every action within 0.08% and 6.5 objects).
  #
  # Only valid evidence is compared: two complete reports of this version
  # (every collection present, rows with unique keys, every warm vector one
  # value per run), at least two runs each, every command exiting 0, no
  # dropped samples, every window finished, one known Ruby and environment;
  # and the same capture identity (the command's arguments, or for
  # --workloads the manifest and every run's measured request sequence, once
  # the run finished at least one measured request in one process that
  # opened no other request windows, not the output directory), seed and
  # number of runs. A kind of window is
  # compared when every run of both reports has some; one some runs have and
  # others lack, or no comparable kind at all, is not evidence. Otherwise
  # #status is 2 (insufficient evidence), whatever the numbers say. A line one
  # side never reached is a measured zero there, but an action one side did
  # not run, or that has no warm value (it ran once per process), is not
  # compared.
  class ProfileCompare
    ACTION_SHARE = 0.001
    ACTION_MIN = 20
    KINDS = %w[request job mail cable].freeze

    Change = Struct.new(:kind, :what, :name, :base, :head, :noise, keyword_init: true) do
      def delta = head - base

      def threshold(min)
        what == "line" ? [noise, min].max : [2 * noise, ACTION_SHARE * [base, head].max, ACTION_MIN * min].max
      end
    end

    attr_reader :not_compared

    def initialize(base, head, min: 1.0, top: 20)
      @base, @head = [base, head].map { |file| JSON.parse(File.read(file)) rescue nil }
      @min = min
      @top = top
      @not_compared = []
    end

    # Why the two reports are not evidence for a comparison (empty when they are).
    def problems
      @problems ||= begin
        list = { "base" => @base, "head" => @head }.flat_map { |label, report| report_problems(label, report) }
        if list.empty?
          %w[identity seed runs ruby rails_env].each do |key|
            b, h = @base["meta"][key], @head["meta"][key]
            list << "base and head differ in #{key}: #{b.to_json} and #{h.to_json}" if b != h
          end
          partial = KINDS.select { |kind| counts(kind).uniq.size > 1 && counts(kind).include?(false) }
          list << "#{partial.join(", ")} windows ran in some runs only" if partial.any?
          list << "no kind of window ran in every run of both reports" if partial.empty? && kinds.empty?
        end
        list
      end
    end

    # One strict check of a report's shape before any arithmetic: every key
    # compare reads is present with its type, rows have unique keys, and
    # anything unexpected is a problem (exit 2), never a crash or a zero.
    def report_problems(label, report)
      meta = report.is_a?(Hash) && report["meta"]
      return ["#{label} is not a report.json of this lowrail-profile (no capture metadata)"] unless meta.is_a?(Hash) && meta["format"] == 2
      runs = meta["runs"]
      return ["#{label} has no run count"] unless runs.is_a?(Integer) && runs > 0
      list = []
      count = ->(v) { v.is_a?(Integer) && v >= 0 }
      list << "#{label} has #{runs} run(s); a noise floor needs at least 2" if runs < 2
      list.concat(identity_problems(label, meta["identity"], runs))
      list << "#{label} has no seed" unless meta["seed"].is_a?(String) && !meta["seed"].empty?
      ruby, env = meta["ruby"], meta["rails_env"]
      unless ruby.is_a?(Array) && ruby.size == 1 && ruby[0].is_a?(String) && !ruby[0].empty? &&
          env.is_a?(Array) && env.size == 1 && env[0].is_a?(String)
        list << "#{label} does not record one known Ruby and environment (#{ruby.to_json}, #{env.to_json})"
      end
      exits = meta["exit"]
      list << "#{label}'s command exited #{exits.to_json}" unless exits.is_a?(Array) && exits.size == runs && exits.all?(0)
      dropped = meta["dropped"]
      list << "#{label} dropped samples (#{dropped.to_json})" unless dropped.is_a?(Array) && dropped.size == runs && dropped.all?(0)
      summary = report["summary"]
      unless summary.is_a?(Array) && summary.size == runs && summary.all? do |run|
          run.is_a?(Hash) && %w[windows completed].all? { |k| run[k].is_a?(Hash) && KINDS.all? { count.(run[k][_1]) } } &&
            count.(run["processes"]) && run["objects_per_request"].is_a?(Numeric) && run["objects_per_request"].to_f.finite?
        end
        return list << "#{label}'s summary is not one row per run with processes, objects per request, and windows and completed windows of every kind"
      end
      # A workloads certificate covers its run only if that run is one process
      # whose request windows are exactly the requests it measured (a fork or
      # an at_exit request would add windows the certificate does not cover).
      measured = meta["identity"].is_a?(Hash) && meta["identity"]["mode"] == "workloads" && meta["identity"]["measured"]
      if measured.is_a?(Array) && measured.size == runs && measured.all?(Hash)
        uncovered = summary.zip(measured).reject { |run, m| run["processes"] == 1 && run["windows"]["request"] == m["requests"] }
        list << "#{label} has #{uncovered.size} run(s) whose request windows are not the one process's measured requests" if uncovered.any?
      end
      list << "#{label} has a run without requests, jobs, mails or Cable actions" if summary.any? { |run| KINDS.sum { run["windows"][_1] } == 0 }
      open = summary.reject { |run| KINDS.all? { run["windows"][_1] == run["completed"][_1] } }
      list << "#{label} has #{open.size} run(s) with windows that never finished, which no line or action counts" if open.any?
      outside = report["outside_requests"]
      return list << "#{label} has no outside_requests" unless outside.is_a?(Hash)
      KINDS.each do |kind|
        source = kind == "request" ? report : outside[kind]
        { "ranked" => "site", "actions" => "name" }.each do |key, id|
          entries = source.is_a?(Hash) && source[key]
          next list << "#{label} has no #{kind} #{key}" unless entries.is_a?(Array) && entries.all?(Hash)
          actions = key == "actions"
          names = entries.map { _1[id] }
          unless names.all? { _1.is_a?(String) || (actions && _1.nil?) } && names.uniq.size == names.size
            list << "#{label} has #{kind} #{key} without a unique #{id}"
          end
          bad = entries.count do |e|
            warm = e["warm"]
            !(warm.is_a?(Array) && warm.size == runs && warm.all? { (actions && _1.nil?) || (_1.is_a?(Numeric) && _1.to_f.finite?) })
          end
          list << "#{label} has #{bad} #{kind} #{key} without one finite warm value per run" if bad > 0
        end
      end
      list
    end

    # A command's arguments, or a workloads capture: its manifest, host, and
    # per run the requests it measured once it finished, all certified.
    def identity_problems(label, identity, runs)
      case identity.is_a?(Hash) && identity["mode"]
      when "command"
        argv = identity["argv"]
        argv.is_a?(Array) && !argv.empty? && argv.all? { _1.is_a?(String) } ? [] : ["#{label}'s command identity has no arguments"]
      when "workloads"
        list = []
        known = ->(v) { v.is_a?(String) && !v.empty? }
        list << "#{label} has no workloads manifest or host" unless known.(identity["manifest"]) && known.(identity["host"])
        measured = identity["measured"]
        unless measured.is_a?(Array) && measured.size == runs && measured.all? do |m|
            m.is_a?(Hash) && m["complete"] == true && known.(m["sha256"]) && m["requests"].is_a?(Integer) && m["requests"] >= 1
          end
          return list << "#{label} does not record that every run finished measuring at least one request"
        end
        names = measured.flat_map { Array(_1["uncertified"]) }.uniq
        list << "#{label} sends env: values a digest cannot certify (#{names.join(", ")}): it is not CI evidence" if names.any?
        list << "#{label}'s runs measured different requests" if measured.map { _1["sha256"] }.uniq.size > 1
        list
      else
        ["#{label} has no known capture identity (profile it again with this lowrail-profile)"]
      end
    end

    def valid? = problems.empty?

    # 0 no regression, 1 a regression, 2 not valid evidence.
    def status = !valid? ? 2 : regressions.empty? ? 0 : 1

    def windows(run) = run.is_a?(Hash) && run["windows"].is_a?(Hash) ? run["windows"] : {}

    # Per run of both reports: whether it has windows of the kind.
    def counts(kind) = [@base, @head].flat_map { |r| Array(r["summary"]).map { windows(_1)[kind].to_i > 0 } }

    def mean(values) = values.sum / values.size

    # The spread of a report's runs: largest minus smallest.
    def spread(values) = values.size > 1 ? values.max - values.min : 0.0

    # Kinds every run of both reports has windows of.
    def kinds = KINDS.select { |kind| counts(kind).all? }

    def lines(report, kind)
      list = kind == "request" ? report["ranked"] : report.dig("outside_requests", kind, "ranked")
      Array(list).to_h { [_1["site"], { value: mean(_1["warm"]), noise: spread(_1["warm"]) }] }
    end

    def actions(report, kind)
      list = kind == "request" ? report["actions"] : report.dig("outside_requests", kind, "actions")
      Array(list).to_h { [_1["name"] || "(no name)", _1["warm"]] }
    end

    def changes
      @changes ||= valid? ? kinds.flat_map { |kind| line_changes(kind) + action_changes(kind) } : []
    end

    def line_changes(kind)
      base, head = lines(@base, kind), lines(@head, kind)
      (base.keys | head.keys).map do |name|
        b, h = base[name], head[name]
        Change.new(kind: kind, what: "line", name: name, base: b ? b[:value] : 0.0, head: h ? h[:value] : 0.0,
          noise: [b ? b[:noise] : 0.0, h ? h[:noise] : 0.0].max)
      end
    end

    def action_changes(kind)
      base, head = actions(@base, kind), actions(@head, kind)
      (base.keys | head.keys).filter_map do |name|
        b, h = base[name], head[name]
        unless b && h && !b.empty? && !h.empty? && !b.include?(nil) && !h.include?(nil)
          @not_compared << { kind: kind, name: name, reason: b && h ? "no warm value" : "ran in #{b ? "base" : "head"} only" }
          next
        end
        Change.new(kind: kind, what: "action", name: name, base: mean(b), head: mean(h), noise: [spread(b), spread(h)].max)
      end
    end

    def regressions = changes.select { _1.delta > _1.threshold(@min) }.sort_by { -_1.delta }
    def improvements = changes.select { -_1.delta > _1.threshold(@min) }.sort_by { _1.delta }

    def total(report) = Array(report["summary"]).map { _1["objects_per_request"] if _1.is_a?(Hash) }.compact

    def markdown
      out = +"# Lowrail profile compare\n\n"
      out << "Base: `#{@base["command"]}`. Head: `#{@head["command"]}`.\n\n" if @base.is_a?(Hash) && @head.is_a?(Hash) && (@base["command"] || @head["command"])
      unless valid?
        out << "## Insufficient evidence\n\nThese reports are not a valid comparison (exit 2):\n\n"
        problems.each { out << "* #{_1}\n" }
        return out << "\n"
      end
      base_total, head_total = total(@base), total(@head)
      unless base_total.empty? || head_total.empty?
        out << "Objects per request (all, by run): base #{base_total.map { _1.round(1) }.join(" / ")}, " \
          "head #{head_total.map { _1.round(1) }.join(" / ")}.\n\n"
      end
      out << "A change counts when it exceeds the noise floor: for a line the larger run-to-run spread in either " \
        "report and at least #{@min} objects per request (warm); for an action twice that spread, " \
        "#{(ACTION_SHARE * 100).round(1)}% of its objects and at least #{ACTION_MIN * @min}. Compared: #{kinds.join(", ")}.\n\n"
      { "Regressions" => regressions, "Improvements" => improvements }.each do |title, list|
        out << "## #{title}: #{list.size}\n\n"
        next out << "None.\n\n" if list.empty?
        out << "| Kind | Line or action | Base | Head | Δ | Noise floor |\n| --- | --- | ---: | ---: | ---: | ---: |\n"
        list.first(@top).each do |c|
          name = c.what == "line" ? "`#{c.name}`" : c.name
          out << "| #{c.kind} #{c.what} | #{name} | #{c.base.round(2)} | #{c.head.round(2)} | " \
            "#{format("%+.2f", c.delta)} | #{c.threshold(@min).round(2)} |\n"
        end
        out << "\n#{list.size - @top} more in the JSON.\n" if list.size > @top
        out << "\n"
      end
      unless not_compared.empty?
        out << "Not compared: #{not_compared.size} actions (#{not_compared.group_by { _1[:reason] }.map { "#{_2.size} #{_1}" }.join(", ")}).\n"
      end
      out
    end

    def to_h
      row = ->(c) { { kind: c.kind, what: c.what, name: c.name, base: c.base, head: c.head, delta: c.delta, noise_floor: c.threshold(@min) } }
      { status: status, problems: problems, min: @min, compared: valid? ? kinds : [], regressions: regressions.map(&row),
        improvements: improvements.map(&row), not_compared: (changes; not_compared) }
    end
  end
end

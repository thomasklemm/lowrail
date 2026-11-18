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
  # (every collection present, every warm vector one value per run), at least
  # two runs each, every command exiting 0, no dropped samples, one Ruby and
  # environment; and the same capture identity (the command's arguments, or
  # for --workloads the manifest and every run's measured request sequence,
  # not the output directory), seed and number of runs. A kind of window is
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
      @base = JSON.parse(File.read(base))
      @head = JSON.parse(File.read(head))
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

    def report_problems(label, report)
      meta = report.is_a?(Hash) && report["meta"]
      return ["#{label} is not a report.json of this lowrail-profile (no capture metadata)"] unless meta.is_a?(Hash) && meta["format"] == 2
      list = []
      runs = meta["runs"]
      return ["#{label} has no run count"] unless runs.is_a?(Integer)
      identity = meta["identity"]
      list << "#{label} has no capture identity (profile it again with this lowrail-profile)" unless identity.is_a?(Hash) && identity["mode"]
      list << "#{label} has no seed" unless meta["seed"].is_a?(String)
      if identity.is_a?(Hash) && identity["mode"] == "workloads"
        measured = Array(identity["measured"])
        list << "#{label} has no workloads manifest" unless identity["manifest"].is_a?(String)
        unless measured.size == runs && measured.all? { _1.is_a?(Hash) && _1["sha256"] }
          list << "#{label} does not record the requests each run measured"
        end
        list << "#{label}'s runs measured different requests" if measured.map { _1.is_a?(Hash) && _1["sha256"] }.uniq.size > 1
      end
      summary = report["summary"]
      return list << "#{label} has no summary" unless summary.is_a?(Array) && summary.all?(Hash)
      list << "#{label} has #{runs} run(s); a noise floor needs at least 2" if runs < 2
      list << "#{label}'s summary has #{summary.size} run(s), its metadata #{runs}" if summary.size != runs
      exits = Array(meta["exit"])
      list << "#{label}'s command exited #{exits.empty? ? "unknown" : exits.join(", ")}" unless exits.size == runs && exits.all?(0)
      dropped = Array(meta["dropped"])
      list << "#{label} dropped samples (#{dropped.join(", ")})" unless dropped.size == runs && dropped.all?(0)
      list << "#{label} has a run without requests, jobs, mails or Cable actions" if summary.any? { windows(_1).values.sum == 0 }
      list << "#{label} ran on more than one Ruby or environment" if Array(meta["ruby"]).size != 1 || Array(meta["rails_env"]).size != 1
      KINDS.each do |kind|
        source = kind == "request" ? report : report.dig("outside_requests", kind)
        %w[ranked actions].each do |key|
          entries = source.is_a?(Hash) && source[key]
          next list << "#{label} has no #{kind} #{key}" unless entries.is_a?(Array) && entries.all?(Hash)
          nils = key == "actions"
          bad = entries.count do |e|
            warm = e["warm"]
            !(warm.is_a?(Array) && warm.size == runs && warm.all? { (nils && _1.nil?) || (_1.is_a?(Numeric) && _1.to_f.finite?) })
          end
          list << "#{label} has #{bad} #{kind} #{key} without one finite warm value per run" if bad > 0
        end
      end
      list
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

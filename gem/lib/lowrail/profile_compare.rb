# frozen_string_literal: true

require "json"

module Lowrail
  # lowrail-profile compare BASE.json HEAD.json: warm objects per request (and
  # per job, mail and Action Cable action) by line outside the app and by
  # action, head minus base. A change counts as a regression when it is larger
  # than the noise floor: for a line, the bigger of the two reports' own
  # run-to-run difference and --min objects; for an action, twice that
  # difference, 0.1% of its objects and 20 times --min, because parallel test
  # workers split an action's requests differently from run to run (A/A on
  # Campfire: every action within 0.08% and 6.5 objects). Actions that ran
  # once per process have no warm value and are not compared.
  class ProfileCompare
    ACTION_SHARE = 0.001
    ACTION_MIN = 20

    Change = Struct.new(:kind, :what, :name, :base, :head, :noise, keyword_init: true) do
      def delta = head - base

      def threshold(min)
        what == "line" ? [noise, min].max : [2 * noise, ACTION_SHARE * [base, head].max, ACTION_MIN * min].max
      end
    end

    def initialize(base, head, min: 1.0, top: 20)
      @base = JSON.parse(File.read(base))
      @head = JSON.parse(File.read(head))
      @min = min
      @top = top
    end

    def mean(values) = values.empty? ? 0.0 : values.sum / values.size

    # A/A difference within one report: last run minus first.
    def spread(values) = values.size > 1 ? (values.last - values.first).abs : 0.0

    def lines(report, kind)
      list = kind == "request" ? report["ranked"] : report.dig("outside_requests", kind, "ranked")
      (list || []).to_h { [_1["site"], { value: mean(_1["warm"]), noise: spread(_1["warm"]) }] }
    end

    def actions(report, kind)
      list = kind == "request" ? report["actions"] : report.dig("outside_requests", kind, "actions")
      (list || []).reject { _1["warm"].include?(nil) }.to_h do |a|
        [a["name"] || "(no name)", { value: mean(a["warm"]), noise: spread(a["warm"]) }]
      end
    end

    def changes
      @changes ||= %w[request job mail cable].flat_map do |kind|
        { "line" => method(:lines), "action" => method(:actions) }.flat_map do |what, reader|
          base, head = reader.(@base, kind), reader.(@head, kind)
          (base.keys | head.keys).map do |name|
            b, h = base[name], head[name]
            Change.new(kind: kind, what: what, name: name, base: b ? b[:value] : 0.0, head: h ? h[:value] : 0.0,
              noise: [b ? b[:noise] : 0.0, h ? h[:noise] : 0.0].max)
          end
        end
      end
    end

    def regressions = changes.select { _1.delta > _1.threshold(@min) }.sort_by { -_1.delta }
    def improvements = changes.select { -_1.delta > _1.threshold(@min) }.sort_by { _1.delta }

    def total(report) = (report["summary"] || []).map { _1["objects_per_request"] }

    def markdown
      out = +"# Lowrail profile compare\n\n"
      out << "Base: `#{@base["command"]}`. Head: `#{@head["command"]}`.\n\n" if @base["command"] || @head["command"]
      base_total, head_total = total(@base), total(@head)
      unless base_total.empty? || head_total.empty?
        out << "Objects per request (all, by run): base #{base_total.map { _1.round(1) }.join(" / ")}, " \
          "head #{head_total.map { _1.round(1) }.join(" / ")}.\n\n"
      end
      out << "A change counts when it exceeds the noise floor: for a line the larger run-to-run difference in either " \
        "report and at least #{@min} objects per request (warm); for an action twice that difference, " \
        "#{(ACTION_SHARE * 100).round(1)}% of its objects and at least #{ACTION_MIN * @min}. Actions that ran once per process are " \
        "not compared.\n\n"
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
      out
    end

    def to_h
      row = ->(c) { { kind: c.kind, what: c.what, name: c.name, base: c.base, head: c.head, delta: c.delta, noise_floor: c.threshold(@min) } }
      { min: @min, regressions: regressions.map(&row), improvements: improvements.map(&row) }
    end
  end
end

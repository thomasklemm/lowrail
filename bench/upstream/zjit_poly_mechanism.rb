# frozen_string_literal: true

# Classify ZJIT polymorphism fallbacks by mechanism (docs/upstream/zjit-polymorphism.md).
#   ruby zjit_poly_mechanism.rb INTERP_DIR JIT_DIR [INTERP_DIR JIT_DIR ...]
# Share of fallbacks by mechanism: one class at the site (shape/profile loss),
# singleton-object receivers, singleton-class (class-level) receivers.
dirs = ARGV.each_slice(2).to_a
dirs.each do |int, jit|
  acc = Hash.new { |h, k| h[k] = Hash.new(0) }
  Dir[File.join(jit, "*.tsv")].each do |jf|
    app = File.basename(jf, ".tsv")
    classes = Hash.new { |h, k| h[k] = {} }
    File.foreach(File.join(int, "#{app}.tsv")) do |l|
      kind, _, label, _, type = l.chomp.split("\t")
      next unless %w[send getivar invokeblock].include?(kind)
      idx = l.split("\t")[1].split(":").last
      classes["#{label}@#{idx}"][type.gsub(/0x\h+/, "")] = true
    end
    File.foreach(jf) do |l|
      kind, iseq_idx, label, _, type, _, n = l.chomp.split("\t")
      next if kind.end_with?("/cme") || n.nil?
      site = "#{label}@#{iseq_idx.split(':').last}"
      k = classes[site].size
      m = if type.start_with?("singleton:obj") then "singleton object"
          elsif type.start_with?("#<Class:") then "class-level (singleton class)"
          elsif k == 1 then "one class at site"
          else "several classes" end
      acc[kind][m] += n.to_i
      acc[kind][:total] += n.to_i
    end
  end
  puts "== #{jit}"
  acc.sort_by { -_2[:total] }.each do |kind, h|
    t = h.delete(:total)
    puts "#{kind}: " + h.sort_by { -_2 }.map { |m, n| "#{m} #{(100.0 * n / t).round}%" }.join(", ")
  end
end

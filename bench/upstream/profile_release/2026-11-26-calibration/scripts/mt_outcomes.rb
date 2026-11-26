# mt_outcomes.rb LOG [RUN]: per-test outcomes of a minitest -v log, sorted, tolerating stderr written mid-line
# (Postgres notices, ffmpeg, Ruby warnings): each "Class#test = " is paired with the next "N.NN s = X".
log = File.binread(ARGV[0]).force_encoding("UTF-8").scrub
if ARGV[1]
  parts = log.split(/^lowrail-profile: run (\d+) of \d+:.*$/)
  i = parts.index(ARGV[1]) or abort "no run #{ARGV[1]}"
  log = parts[i + 1]
end
out = []
name = nil
log.each_line do |l|
  if (m = l.match(/\A(\S+#\S+) = /)) then name = m[1]; l = m.post_match end
  if name && (m = l.match(/(?:\A| )[\d.]+ s = ([.SEF])\s*\z/)) then out << "#{name} #{m[1]}"; name = nil end
end
puts out.sort

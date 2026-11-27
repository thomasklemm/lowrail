require 'hashie'; require 'json'; require 'logger'; require 'stackprof'
Hashie.logger = Logger.new(nil)
src = JSON.parse(File.read('benchmarks/fixtures/repository.json'))
5000.times { Hashie::Mash.new(src) }
prof = StackProf.run(mode: :cpu, interval: 50, raw: true) { 30000.times { Hashie::Mash.new(src) } }
StackProf::Report.new(prof).print_text(false, 25)

require "json"
dir = "/home/user/workspace/repo/.lowrail/private/rails-main-census-3"
med = ->(a) { a.sort[1] }
puts "| Patch | Mode | Blog | Campfire | Fizzy | Writebook |"
puts "| --- | --- | ---: | ---: | ---: | ---: |"
%w[base2 where arel warnings all].each do |label|
  %w[interpreter yjit].each do |mode|
    cells = %w[blog campfire fizzy writebook].map do |app|
      a = JSON.parse(File.read("#{dir}/#{app}-#{mode}.json"))["routes"]
      b = JSON.parse(File.read("#{dir}/after-#{label}/#{app}-#{mode}.json"))["routes"]
      a.zip(b).map { |x, y| format("%+.1f", med.(y["gc_enabled_objects_per_request"]) - med.(x["gc_enabled_objects_per_request"])) }.join(" / ")
    end
    puts "| #{label} | #{mode} | #{cells.join(' | ')} |"
  end
end

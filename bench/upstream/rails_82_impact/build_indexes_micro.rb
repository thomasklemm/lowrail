# Ir per IndexedRow.build_indexes call: main (Array#index_with via to_h), 8.1's
# while loop, each_with_index, each_with_index.to_h. Under cachegrind, run with
# K=0 and K=20000 and divide the difference by 20000:
#   ruby build_indexes_micro.rb 81|main|ewi|zip N K
v, n, k = ARGV[0], Integer(ARGV[1]), Integer(ARGV[2])
class Array
  def index_with_main(default = (no_default = true))   # main: Array#index_with
    if block_given?
      to_h { |elem| [elem, yield(elem)] }
    else
      to_h { |elem| [elem, default] }
    end
  end
end
def bi_main(columns) = (index = -1; columns.index_with_main { index += 1 })
def bi_81(columns)
  index = 0; hash = {}; length = columns.length
  while index < length
    hash[columns[index]] = index
    index += 1
  end
  hash
end
def bi_ewi(columns) = (h = {}; columns.each_with_index { |c, i| h[c] = i }; h)
def bi_zip(columns) = columns.each_with_index.to_h
cols = Array.new(n) { |i| -"column_#{i}" }
m = method(:"bi_#{v}")
raise "mismatch" unless m.call(cols) == bi_81(cols)
k.times { m.call(cols) }

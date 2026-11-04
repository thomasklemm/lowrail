require_relative "/home/user/w/scratch/setup"
ActiveRecord::Schema.define { create_table(:comments) { |t| t.integer :post_id; t.string :body } }
class Comment < ActiveRecord::Base; belongs_to :post; end
class Post; has_many :comments; end
class Author; has_many :comments, through: :posts; end
r = Author.reflect_on_association(:comments)
d = r.send(:delegate_reflection)
puts RubyVM::InstructionSequence.of(r.method(:options)).disasm.lines.first(30).join
def m(l, n=2_000_000); b=1e9; 5.times { t=Process.clock_gettime(Process::CLOCK_MONOTONIC); i=0; while i<n; yield; i+=1; end; b=[b,Process.clock_gettime(Process::CLOCK_MONOTONIC)-t].min }; printf "%-30s %6.1f ns\n", l, b*1e9/n; end
m("through.options") { r.options }
m("delegate_reflection.options") { d.options }
m("through_reflection") { r.through_reflection }

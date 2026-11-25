module R; refine(Integer) { def double = self * 2 }; end
def foo = yield(3)
def plain = foo(&:double)
def plain_c = [3].flat_map(&:double)
module M
  using R
  def self.refined = foo(&:double)
  def self.t = [(plain rescue $!.class), (plain_c rescue $!.class), refined]
end
def outer_plain = (M.refined rescue $!.class)
p 50.times.map { [M.t, outer_plain] }.uniq

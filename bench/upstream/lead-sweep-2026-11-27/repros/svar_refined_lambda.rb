# A Symbol proc cached under a refinement keeps the svar frame of the method that first built it.
module R; refine(String) { def match(re) = super }; end
using R
def y2(s, re) = yield(s, re)
def sv = (y2("abc", /b/, &:match); $~)
def deeper = sv
p sv
p deeper
p deeper

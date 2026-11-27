$a[0] as $o | $b[0] | to_entries[] | .key as $k | .value as $v | ($o[$k] // {}) as $w |
(if $w=={} then "NEWPR \($k) \($v.state)" else empty end),
(if ($w.state? and $w.state!=$v.state) then "STATE \($k) \($w.state)->\($v.state) merged=\($v.merged) by=\($v.merged_by)" else empty end),
(if ($w.draft!=null and $w.draft!=$v.draft) then "DRAFT \($k) \($v.draft)" else empty end),
(if ($w.head? and $w.head!=$v.head) then "HEAD \($k) \($w.head[0:10])->\($v.head[0:10])" else empty end),
(if (($w.labels//null)!=null and $w.labels!=$v.labels) then "LABELS \($k) \($v.labels)" else empty end),
( (($v.com//[])+($v.rev//[])+($v.rc//[]))[] | . as $c | select(([($w.com//[])+($w.rev//[])+($w.rc//[]) | .[].id] | index($c.id)) == null) | "NEW \($k) \($c.u) \($c.a//$c.s//"") \($c.t): \($c.b|gsub("\n";" ")|.[0:180])"),
( ($v.cm//[])[] | . as $c | select(([($w.cm//[])[].sha] | index($c.sha))==null) | "COMMIT \($k) \($c.a) \($c.m)"),
(if ($k|test("^https://github.com/(rails/rails|freerange/mocha)/pull")) and $v.state=="open" and $v.status.state!=($w.status.state//"") then "CI \($k) \($w.status.state//"-")->\($v.status.state) \([$v.status.s[]|.c+":"+.s]|join(","))" else empty end),
(if ($k|startswith("https:")) and ($k|test("rails/rails")|not) and $v.state=="open" and (([$v.checks.bad[]?|select(.c!=null)|.n]|sort)!=([$w.checks.bad[]?|select(.c!=null)|.n]|sort)) then "CK \($k) \([$v.checks.bad[]?|select(.c!=null)|.n+":"+.c]|join(",")|.[0:300])" else empty end)
,
(if ($k|test("ruby/ruby-bench/pull/56[67]$")) and $v.state=="open" and $v.mstate=="dirty" and ($w.mstate//"")!="dirty" then "CONFLICT \($k) mergeable_state dirty" else empty end)
,
(if ($k|startswith("gem:")) and ($w.version? != null) and $w.version != $v.version then "GEM \($k) \($w.version) -> \($v.version)" else empty end)
,
(if ($k|startswith("run:")) and ($w.status? != null) and ($w.status != $v.status or $w.conclusion != $v.conclusion) then "RUN \($k) \($v.branch) \($w.status)/\($w.conclusion) -> \($v.status)/\($v.conclusion)" else empty end)
,
(if ($k|startswith("repo:")) and ($w != {}) and $w != $v then "REPO \($k) \([$v|to_entries[]|select($w[.key] != .value)|"\(.key): \($w[.key]) -> \(.value)"]|join("; "))" else empty end)
,
(if ($k=="foreign:ruby/ruby/pull/18616") and ($w.nse? != null) and $w.nse != $v.nse then "NSE \($k) no_side_exits diff lines \($w.nse) -> \($v.nse)" else empty end)

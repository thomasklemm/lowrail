Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `where(id: 20 ids), miss` | 266 | 266 | 1,581,836 | 1,458,428 | −7.8% |
| `where(id: 20 ids), hit` | 169 | 169 | 1,313,922 | 1,196,484 | −8.9% |
| `where(id: 100 ids), miss` | 986 | 986 | 6,171,360 | 5,558,258 | −9.9% |
| `where(id: 100 ids), hit` | 569 | 569 | 5,281,970 | 4,699,696 | −11.0% |

Record (not for the body): the run was stopped after the interpreter cells (the YJIT Callgrind cells take about
three minutes per dump on this orb; there is no IN-list JIT evidence in this directory), so
script/upstream-bench wrote no results.json. Instructions per call = (n2000 total − n0 total) / 2000 from each
dump's `totals:` line in callgrind-dumps.tar.xz; base = mean of base and base2.
- A/A (|base2 − base| / base): 20 miss 0.008%, 20 hit 0.017%, 100 miss 0.014%, 100 hit 0.014%
- base / base2 / candidate: 20 miss 1,581,770 / 1,581,902 / 1,458,428; 20 hit 1,313,809 / 1,314,035 / 1,196,484;
  100 miss 6,170,921 / 6,171,800 / 5,558,258; 100 hit 5,282,343 / 5,281,596 / 4,699,696
- Objects from raw/objects-*.log, identical for base, base2 and candidate (YJIT: 268, 171, 988, 571, also identical)
- Binds are ActiveModel::Attribute::WithCastValue (hash not memoized), so main hashes every id twice per lookup.

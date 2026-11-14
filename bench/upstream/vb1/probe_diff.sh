#!/bin/bash
# probe_diff.sh MAIN.txt FIX.txt: diff two probe outputs after dropping the block frames the branch adds to
# backtraces (the block in fetch_value_at!/value_at! between cast_value and value!, the block in deep_dup between
# Object#deep_dup and transform_attributes!) and the frame counts. Empty output: same values, messages, casts and
# the same backtraces apart from those frames.
norm() {
  sed -E 's/ \| activemodel\/lib\/active_model\/attribute_set\.rb:(412|534) (fetch_value_at!|value_at!)( \| activemodel\/lib\/active_model\/attribute_set\.rb:570 cast_value)/\3/
    s/(deep_dup\.rb:18 deep_dup) \| activemodel\/lib\/active_model\/attribute_set\.rb:444 deep_dup( \| activemodel\/lib\/active_model\/attribute_set\.rb:476 transform_attributes!)/\1\2/
    s/backtrace\([0-9]+\)/backtrace(N)/' "$1"
}
diff <(norm "$1") <(norm "$2")

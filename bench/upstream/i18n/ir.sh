#!/usr/bin/env bash
# ir.sh I18N_LIB_DIR SETUP_RB EXPR [N]: Callgrind instructions per evaluation of EXPR, (Ir(N) - Ir(0)) / N
# after 500 warm-up calls; SETUP_RB loads i18n and stores translations (setup_fallbacks.rb).
export PATH=${RUBY_BIN:-$HOME/.local/share/mise/installs/ruby/4.0.7/bin}:$PATH
lib=$1 setup=$2 expr=$3 n=${4:-5000}
run() { valgrind --tool=callgrind --callgrind-out-file=/dev/null ruby -I"$lib" -e "load '$setup'; f = -> { $expr }; 500.times { f.() }; $1.times { f.() }" 2>&1 | rg -o 'Collected : \d+' | rg -o '\d+'; }
a=$(run 0); b=$(run $n)
echo $(( (b - a) / n ))

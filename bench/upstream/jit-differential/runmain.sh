#!/bin/bash
export RAILS_DIR=$HOME/jitdiff/rails-main EXTRA_ARGS="--exclude /ractor/i"
exec ./run.sh "$@"

#!/bin/bash
# dispatch.sh KIND BUILD MODE COMP TAG ; KIND = main | old | app
k=$1; shift
cd ~/jitdiff
case $k in main) ./runmain.sh "$@";; old) ./run.sh "$@";; app) ./runapp.sh "$@";; esac

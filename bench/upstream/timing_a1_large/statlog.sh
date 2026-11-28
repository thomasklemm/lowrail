#!/bin/bash
# Appends a timestamped /proc/stat snapshot every 15 s.
while true; do echo "T $(date -u +%s)"; grep -E '^cpu' /proc/stat; sleep 15; done >> /tmp/logs/procstat.log

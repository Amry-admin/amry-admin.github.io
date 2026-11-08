#!/usr/bin/env bash
# Runs a command; on failure, surfaces the tail of its output as a GitHub
# annotation (readable without opening the logs) and fails the step.
set -u
title="$1"; shift
out=$(mktemp)
"$@" > "$out" 2>&1
code=$?
cat "$out"
if [ $code -ne 0 ]; then
  msg=$(grep -v '^\s*$' "$out" | tail -c 3500 | sed ':a;N;$!ba;s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g')
  echo "::error title=$title::$msg"
else
  echo "::notice title=$title::$(grep -v '^\s*$' "$out" | tail -1)"
fi
rm -f "$out"
exit $code

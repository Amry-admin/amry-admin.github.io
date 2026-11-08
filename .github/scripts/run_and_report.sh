#!/usr/bin/env bash
# Runs a command; on failure, surfaces its output as GitHub annotations
# (readable without opening the logs) and fails the step.
set -u
title="$1"; shift
out=$(mktemp)
"$@" > "$out" 2>&1
code=$?
cat "$out"
if [ $code -ne 0 ]; then
  # Keep the useful lines (analyzer issues, test failures, compiler errors).
  grep -E "error •|warning •|info •|Error:|error:|FAILED|Expected:|Actual:|Exception|issues? found|tests? (passed|failed)|Some tests failed|\[E\]" "$out" \
    | grep -v '^\s*$' > "$out.key" || true
  [ -s "$out.key" ] || tail -c 6000 "$out" > "$out.key"
  # Up to 8 annotations of ~3000 characters each.
  split -C 3000 -d -a 1 "$out.key" "$out.part."
  n=0
  for f in "$out".part.*; do
    n=$((n+1)); [ $n -gt 8 ] && break
    msg=$(sed ':a;N;$!ba;s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g' "$f")
    echo "::error title=$title ($n)::$msg"
  done
  rm -f "$out".part.* "$out.key"
else
  echo "::notice title=$title::$(grep -v '^\s*$' "$out" | tail -1)"
fi
rm -f "$out"
exit $code

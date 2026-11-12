#!/usr/bin/env bash
#
# rehearse-store.sh — rehearse an app upgrade on a copy of a real store.
#
#   FITBOD_PHONE=<udid> scripts/rehearse-store.sh pull
#   FITBOD_TEST_DEVICE=<simulator udid> scripts/rehearse-store.sh run <store folder> [earlier.fitbodbackup]
#
# Run it before a schema change and again after it (docs/DEVELOPMENT.md:
# "Rehearse every schema change on a copy of the phone's store").
#
# pull: copies Library/Application Support out of the app's data container
#       on the phone into .ci/phone-store/<date>/. Close the app first, so the
#       store and its -wal are not being written. The copy is personal training
#       data: it stays in ignored .ci/ and is never committed. It is also the
#       rollback: `xcrun devicectl device copy to` with the same domain puts
#       it back.
# run:  runs StoreRehearsalTests on a copy of <store folder> (the folder that
#       holds default.store). The copy must open in place with every row and
#       survive a backup round trip. With an earlier backup, that backup must
#       restore to the same data. Results (the opened store, the archive, the
#       row counts) land in <store folder>/../rehearsal-<stamp>/.
#
# The simulator's test host reads and writes /private/tmp, so `run` works on a
# copy there and moves the results back.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID=bodybuilding.fitbod

case "${1:-}" in
pull)
  PHONE="${FITBOD_PHONE:?set FITBOD_PHONE to the UDID of the phone}"
  dest="$ROOT/.ci/phone-store/$(date +%Y-%m-%d-%H%M%S)"
  mkdir -p "$dest"
  xcrun devicectl device copy from --device "$PHONE" \
    --domain-type appDataContainer --domain-identifier "$APP_ID" \
    --source "Library/Application Support" --destination "$dest/Application Support"
  [[ -f "$dest/Application Support/default.store" ]] || { echo "no default.store in the copy" >&2; exit 1; }
  echo "Store copied to $dest/Application Support"
  ;;
run)
  store="${2:?usage: $0 run <store folder> [earlier.fitbodbackup]}"
  earlier="${3:-}"
  [[ -f "$store/default.store" ]] || { echo "$store has no default.store" >&2; exit 1; }
  stamp="$(date +%Y%m%d-%H%M%S)"
  work="/private/tmp/fitbod-rehearsal-$stamp"
  results="$(cd "$store/.." && pwd)/rehearsal-$stamp"
  mkdir -p "$work/out"
  trap 'rm -rf "$work"' EXIT
  cp -R "$store" "$work/store"
  export TEST_RUNNER_FITBOD_REHEARSAL_STORE="$work/store"
  export TEST_RUNNER_FITBOD_REHEARSAL_OUT="$work/out"
  if [[ -n "$earlier" ]]; then
    cp "$earlier" "$work/earlier.fitbodbackup"
    export TEST_RUNNER_FITBOD_REHEARSAL_ARCHIVE="$work/earlier.fitbodbackup"
  fi
  status=0
  "$ROOT/scripts/test.sh" fast -only-testing:fitbodTests/StoreRehearsalTests || status=$?
  mv "$work/out" "$results"
  # A suite that never saw the environment is skipped and passes; the files
  # prove that it ran to the end.
  [[ -f "$results/round-trip/counts.txt" ]] || { echo "the rehearsal did not run to the end; see $results" >&2; exit 1; }
  if [[ -n "$earlier" && ! -f "$results/earlier-archive/restored.txt" ]]; then
    echo "the earlier backup was not restored; see $results" >&2; exit 1
  fi
  [[ $status -eq 0 ]] || { echo "the rehearsal failed; see $results" >&2; exit "$status"; }
  echo "Rehearsal passed. Rows per entity:"
  cat "$results/round-trip/counts.txt"; echo
  echo "Results: $results"
  ;;
*)
  echo "usage: $0 pull | run <store folder> [earlier.fitbodbackup]" >&2
  exit 2
  ;;
esac

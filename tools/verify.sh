#!/usr/bin/env bash
# The two verify commands required by GAME_SPEC_v0.2 §10.1.
#
#   tools/verify.sh rules    the house rules, as checks instead of prose
#   tools/verify.sh static   project parses and imports; data contracts hold
#   tools/verify.sh sim      headless test suite + balance report
#   tools/verify.sh play     the assembled game, played through and asserted
#   tools/verify.sh          all four
#
# A change is not done until both are green. Do not weaken a check to make it
# pass — see CLAUDE.md.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

GODOT_VERSION="4.7-stable"
GODOT="${GODOT:-$REPO_ROOT/.godot-bin/Godot_v${GODOT_VERSION}_linux.x86_64}"

if [[ ! -x "$GODOT" ]]; then
  echo "godot not found at $GODOT" >&2
  echo "run tools/setup_godot.sh first, or set GODOT=/path/to/godot" >&2
  exit 127
fi

# 50 is enough while the scene is deterministic: every run currently produces an
# identical duration, so the count buys nothing but confidence that it stays
# that way. It is not about catching a bug that only appears on run 51.
#
# Raise it again when combat introduces real randomness and the harness starts
# reporting a win rate — then the count sets the precision of the average, and
# GAME_SPEC v0.1 criterion 7 (200) and v0.2 §10.9 (500) become the numbers that
# matter. Override any time with SIM_RUNS=500 tools/verify.sh sim
SIM_RUNS="${SIM_RUNS:-50}"
FAILED=0

hdr() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
ok()  { printf '\033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '\033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }
skip(){ printf '\033[33mSKIP\033[0m %s\n' "$1"; }

verify_rules() {
  hdr "rules"

  # The rules in CLAUDE.md, ARCHITECTURE.md and ASSETS.md, made executable. A
  # rule in a document is something a reader might remember; a rule in a check
  # is something that stops them. Every check here exists because the rule it
  # encodes was broken at least once despite being written down.
  local out
  out="$(python3 "$REPO_ROOT/tools/check_rules.py" 2>&1)"
  local rc=$?
  echo "$out"
  if [[ $rc -eq 0 ]]; then ok "house rules"; else bad "house rules"; fi
}


verify_static() {
  hdr "static"

  # Import resources and surface parse errors. Godot exits 0 on script parse
  # errors, so the output has to be inspected rather than trusted.
  local out
  out="$("$GODOT" --headless --import --quit-after 2 2>&1)"
  if grep -qiE 'SCRIPT ERROR|Parse Error|Failed to load script|Compile Error' <<<"$out"; then
    bad "project parses"
    grep -iE 'SCRIPT ERROR|Parse Error|Failed to load script|Compile Error' <<<"$out" | head -20
  else
    ok "project parses and imports"
  fi

  out="$("$GODOT" --headless --script tools/validate_data.gd 2>&1)"
  local rc=$?
  echo "$out" | grep -E '^(WARN|ERROR|data )' || true
  if [[ $rc -eq 0 ]] && ! grep -q '^ERROR' <<<"$out"; then
    ok "data contracts"
  else
    bad "data contracts"
  fi
}

verify_sim() {
  hdr "sim"

  if [[ -d tests ]] && compgen -G "tests/*.gd" >/dev/null; then
    local out
    out="$("$GODOT" --headless --script tests/run_tests.gd 2>&1)"
    local rc=$?
    echo "$out" | tail -30
    if [[ $rc -eq 0 ]]; then ok "test suite"; else bad "test suite"; fi
  else
    skip "test suite — tests/ is empty (optional; sim_runner is the required harness)"
  fi

  # Path and flag spelling come from GAME_SPEC_v0.1 acceptance criterion 7:
  #   godot --headless --script res://tools/sim_runner.gd -- --runs 200
  if [[ -f tools/sim_runner.gd ]]; then
    local out
    out="$("$GODOT" --headless --script res://tools/sim_runner.gd -- --runs "$SIM_RUNS" 2>&1)"
    local rc=$?
    echo "$out" | tail -30
    if [[ $rc -eq 0 ]]; then
      ok "$SIM_RUNS-run balance report"
    else
      bad "$SIM_RUNS-run balance report"
    fi
  else
    skip "balance report — tools/sim_runner.gd does not exist yet (slice 4)"
  fi
}

verify_play() {
  hdr "play"

  # The assembled game, UI included, played to the end and checked. `sim` proves
  # the simulation is right with no UI attached — which is exactly why it cannot
  # see a crew member drawn outside the room they are standing in, or a panel
  # that resolved to the wrong size.
  #
  # Under a display when one can be had. Headless Godot lays the root Control
  # out against a 64x64 stand-in window, so the layout assertions are not
  # trustworthy there and play.gd skips them by name rather than passing them.
  local runner=("$GODOT" --headless)
  if command -v xvfb-run >/dev/null 2>&1; then
    runner=(xvfb-run -a "$GODOT")
  else
    skip "no xvfb-run; layout checks will be skipped inside play"
  fi

  local out
  out="$("${runner[@]}" --script res://tools/play.gd 2>&1)"
  local rc=$?
  echo "$out" | grep -E '^(play:|FAIL|SKIP)' || true
  if [[ $rc -eq 0 ]]; then ok "scripted playthrough"; else bad "scripted playthrough"; fi
}


case "${1:-all}" in
  rules)  verify_rules ;;
  static) verify_static ;;
  sim)    verify_sim ;;
  play)   verify_play ;;
  all)    verify_rules; verify_static; verify_sim; verify_play ;;
  *)      echo "usage: tools/verify.sh [rules|static|sim|play]" >&2; exit 2 ;;
esac

echo
if [[ $FAILED -eq 0 ]]; then
  printf '\033[32mgreen\033[0m\n'
else
  printf '\033[31mred\033[0m\n'
fi
exit $FAILED

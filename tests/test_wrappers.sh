#!/usr/bin/env bash
# test_wrappers.sh — run 08's wrappers (lab/bin): run-gate, run-trial, lab-git.
# They are the boundary between trial code and everything else, so every
# refusal is tested, and a refusal must never run the gate or a session.
# Runs without sudo, in a relocated lab; the scripts honour their *_TEST_*
# variables only when SUDO_USER is unset.
. "$(dirname "$0")/lib.sh"
need git
E="$REPO/experiments/statamic-blueprint-revisions/lab/bin"; B="$BASH_UT"
L="$WORK/lab"; G="$L/gate"
mkdir -p "$L/trials" "$G/spec" "$G/log"
# Stub gate: records what it was given and exits $STUB_RC.
cat > "$G/spec/gate.sh" <<'EOF'
echo "GATE-RAN app=$1 port=$2 lab=$LAB_ROOT audit=$GATE_AUDIT_LOG pw=$PLAYWRIGHT_BROWSERS_PATH" >> "$LAB_ROOT/gate-ran.log"
exit "${STUB_RC:-0}"
EOF
printf 'tA\tA\t59001\tclaude-haiku-5-5\ntB\tB\t59002\tclaude-haiku-5-5\n' > "$G/schedule.tsv"
for t in tA tB tX; do mkdir -p "$L/trials/$t"; done
mkdir -p "$WORK/elsewhere/tB"

rg() { # caller args... -> out, rc
  local c="$1"; shift
  out="$(env -u SUDO_USER RUN_GATE_TEST_ROOT="$L" RUN_GATE_TEST_OWNER=owner RUN_GATE_TEST_CALLER="$c" \
         STUB_RC="${STUB_RC:-0}" "$B" "$E/run-gate" "$@" 2>&1)"; rc=$?
}
ran() { wc -l < "$L/gate-ran.log" 2>/dev/null | tr -d ' '; }
: > "$L/gate-ran.log"

echo "== run-gate: refusals never run the gate"
rg labtrial "$L/trials/tA" 59001; chk "arm A, asked by the trial user -> refused (3)" "$rc" "3"
has "  ...says no acceptance command is available" "$out" "no acceptance command is available"
rg labtrial "$L/trials/tB" 59009; chk "the wrong port for the trial -> refused" "$rc" "3"
rg labtrial "$L/trials/tX" 59003; chk "a trial not on the schedule -> refused" "$rc" "3"
rg labtrial "$WORK/elsewhere/tB" 59002; chk "a same-named dir outside trials/ -> refused" "$rc" "3"
rg labtrial "$L/trials/../trials/tB/.." 59002; chk "a path that resolves to trials/ itself -> refused" "$rc" "3"
rg labtrial "$L/trials/tB" 80; chk "a port that isn't 4-5 digits -> refused" "$rc" "3"
rg labtrial "$L/trials/tB"; chk "a missing argument -> refused" "$rc" "3"
rg labtrial "$L/trials/tB" "59002;id"; chk "shell text in the port -> refused" "$rc" "3"
chk "none of those ran the gate" "$(ran)" "0"
chk "every refusal is in the gate's audit log" "$(grep -c REFUSED "$G/log/gate-audit.log")" "8"

echo "== run-gate: allowed runs"
rg labtrial "$L/trials/tB" 59002; chk "arm B, asked by the trial user -> runs" "$rc" "0"
has "  ...on the resolved trial path and its port" "$(cat "$L/gate-ran.log")" "app=$(cd "$L/trials/tB" && pwd -P) port=59002"
has "  ...with the audit log in the gate area" "$(cat "$L/gate-ran.log")" "audit=$G/log/gate-audit.log"
has "  ...and Playwright's browsers in the gate area" "$(cat "$L/gate-ran.log")" "pw=$G/browsers"
STUB_RC=1 rg owner "$L/trials/tA" 59001; chk "arm A, asked by the owner (scoring) -> runs, RED passed through" "$rc" "1"
chk "the lock is released after a run" "$( [ -e "$G/log/gate.lock" ] && echo held || echo free)" "free"
mkdir "$G/log/gate.lock"; touch -t 202001010000 "$G/log/gate.lock"
rg owner "$L/trials/tB" 59002; chk "a stale lock (over an hour) is taken over" "$rc" "0"
has "  ...and that is logged" "$(cat "$G/log/gate-audit.log")" "STALE LOCK"
# Under sudo the *_TEST_* variables must be dead code. Checked statically, not by
# running with SUDO_USER set: that run would log a refusal in the REAL gate log.
for w in run-gate run-trial lab-git; do
  bad="$(awk '/SUDO_USER:-}" ]/ { inblk = 1 } inblk && /^fi$|; fi$/ { inblk = 0; next }
              /_TEST_/ && !inblk && !/SUDO_USER:-}" \] && / { print NR": "$0 }' "$E/$w")"
  chk "$w reads *_TEST_* only when SUDO_USER is unset" "$bad" ""
done

echo "== run-trial"
H="$WORK/trialhome"; mkdir -p "$H/.config/relay" "$H/bin"
printf 'secret-token\n' > "$H/.config/relay/claude-oauth-token"; chmod 600 "$H/.config/relay/claude-oauth-token"
# Stub claude: records its args, and whether a token arrived (never the token).
cat > "$H/bin/claude" <<'EOF'
#!/bin/sh
echo "ARGS $*"
[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && echo "TOKEN present" || echo "TOKEN absent"
echo "PROMPT $(cat)"
[ -n "${STUB_SLEEP:-}" ] && sleep "$STUB_SLEEP"
exit 0
EOF
chmod +x "$H/bin/claude"
mkdir -p "$L/trials/r1"; echo "build the thing" > "$L/trials/r1.prompt.md"
# run-trial sets HOME from the account database; point it at the stub home.
fake_home_run() { # args -> out, rc, with run-trial's HOME line redirected to $H
  sed "s|^HOME=.*|HOME=\"$H\"|" "$E/run-trial" > "$WORK/run-trial.t"
  out="$(env -u SUDO_USER RUN_TRIAL_TEST_ROOT="$L" RUN_TRIAL_TEST_LIMIT="${LIMIT:-60}" STUB_SLEEP="${STUB_SLEEP:-}" \
         PATH="$H/bin:$PATH" "$B" "$WORK/run-trial.t" "$@" 2>&1)"; rc=$?
}
mkdir -p "$H/.local/bin"; cp "$H/bin/claude" "$H/.local/bin/claude"
fake_home_run r1 claude-sonnet-5-5; chk "a model outside the list -> refused (3)" "$rc" "3"
fake_home_run r1 haiku; chk "an alias, not a full ID -> refused" "$rc" "3"
fake_home_run nope claude-haiku-5-5; chk "a trial with no directory -> refused" "$rc" "3"
mkdir -p "$L/trials/r2"; fake_home_run r2 claude-haiku-5-5; chk "a trial with no prompt -> refused" "$rc" "3"
fake_home_run "r1;id" claude-haiku-5-5; chk "shell text in the trial name -> refused" "$rc" "3"
chmod 644 "$H/.config/relay/claude-oauth-token"; fake_home_run r1 claude-haiku-5-5
chk "a token file readable by others -> refused" "$rc" "3"; chmod 600 "$H/.config/relay/claude-oauth-token"
chk "no refused run wrote a transcript" "$( [ -e "$L/trials/r1.transcript.jsonl" ] && echo yes || echo no)" "no"
fake_home_run r1 claude-haiku-5-5; chk "a valid trial runs (0)" "$rc" "0"
T1="$(cat "$L/trials/r1.transcript.jsonl")"
has "  ...pins the model" "$T1" "--model claude-haiku-5-5"
has "  ...with exactly the six tools" "$T1" "--tools Bash,Read,Edit,Write,Grep,Glob"
has "  ...no MCP servers" "$T1" "--strict-mcp-config"
has "  ...unattended" "$T1" "--permission-mode bypassPermissions"
has "  ...on the trial's prompt" "$T1" "PROMPT build the thing"
has "  ...with the token in its environment" "$T1" "TOKEN present"
hasnt "  ...and the token never in its output" "$T1$(cat "$L/trials/r1.stderr")" "secret-token"
chk "  ...exit status recorded" "$(cat "$L/trials/r1.exit")" "0"
STUB_SLEEP=5 LIMIT=1 fake_home_run r1 claude-haiku-5-5; chk "over the time limit -> 124" "$rc" "124"

echo "== lab-git patch"
R="$L/trials/p1"; git init -q -b main "$R"; echo base > "$R/a.txt"
git -C "$R" add a.txt; git -C "$R" commit -q -m base
echo changed > "$R/a.txt"; echo new > "$R/b.txt"
lg() { out="$(env -u SUDO_USER LAB_GIT_TEST_ROOT="$L" "$B" "$E/lab-git" "$@" 2>&1)"; rc=$?; }
lg patch p1; chk "patch of a trial -> 0" "$rc" "0"
has "  ...includes the tracked change" "$out" "+changed"
has "  ...and the untracked new file" "$out" "+new"
git -C "$R" config core.fsmonitor "touch $WORK/fsmonitor-ran; false"
git -C "$R" config core.pager "touch $WORK/pager-ran; cat"
lg patch p1
chk "a trial's core.fsmonitor never runs" "$( [ -e "$WORK/fsmonitor-ran" ] && echo ran || echo no)" "no"
chk "a trial's core.pager never runs" "$( [ -e "$WORK/pager-ran" ] && echo ran || echo no)" "no"
lg patch "../p1"; chk "a path in the trial name -> refused" "$rc" "3"
lg log p1; chk "anything but patch -> refused" "$rc" "3"

finish

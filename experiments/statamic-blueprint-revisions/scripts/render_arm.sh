#!/usr/bin/env bash
# render_arm.sh <arm> <trial> <port> — create the trial and print its prompt.
#
# Placeholders in the arm files: {{APP_DIR}}, {{PORT}}, {{SPEC_DIR}} (where the
# trial is told the spec lives, default $LAB_ROOT/spec) and {{GATE_CMD}} (the
# acceptance command without its arguments, default `bash $SPEC_DIR/gate.sh`).
# Both are overridable so the gate can move out of a trial's reach (run 07's
# arm-A confound) without editing the arms. A prompt with any placeholder left
# unrendered is refused: run 07's arms hard-coded /home/user/lab, and a prompt
# that points at a path that doesn't exist is a different treatment.
set -euo pipefail
ARM="${1:?arm}"; TRIAL="${2:?trial}"; PORT="${3:?port}"
: "${LAB_ROOT:?set LAB_ROOT — see the experiment README, Rebuilding the lab}"
SPEC_DIR="${SPEC_DIR:-$LAB_ROOT/spec}"
GATE_CMD="${GATE_CMD:-bash $SPEC_DIR/gate.sh}"
SRC="$LAB_ROOT/spec/arms/arm-$ARM.md"
[ -f "$SRC" ] || { echo "render_arm.sh: no arm file $SRC" >&2; exit 2; }
for v in "$SPEC_DIR" "$GATE_CMD" "$PORT"; do
  case "$v" in *'#'*|*'&'*|*'\'*) echo "render_arm.sh: '$v' contains # & or \\, which sed would mangle" >&2; exit 2 ;; esac
done
DIR=$(bash "$(dirname "$0")/new_trial.sh" "$TRIAL")
OUT="$LAB_ROOT/trials/$TRIAL.prompt.md"
sed -e "s#{{APP_DIR}}#$DIR#g" -e "s#{{PORT}}#$PORT#g" \
    -e "s#{{SPEC_DIR}}#$SPEC_DIR#g" -e "s#{{GATE_CMD}}#$GATE_CMD#g" "$SRC" > "$OUT"
if grep -n '{{' "$OUT" >&2; then
  echo "render_arm.sh: unrendered placeholder in $OUT (above); refusing" >&2
  rm -f "$OUT"; exit 3
fi
echo "$DIR"

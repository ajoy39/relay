#!/usr/bin/env bash
# render_arm.sh <arm> <trial> <port> — create the trial and print its prompt.
set -euo pipefail
ARM="${1:?arm}"; TRIAL="${2:?trial}"; PORT="${3:?port}"
: "${LAB_ROOT:?set LAB_ROOT — see the experiment README, Rebuilding the lab}"
DIR=$(bash "$(dirname "$0")/new_trial.sh" "$TRIAL")
sed -e "s#{{APP_DIR}}#$DIR#g" -e "s#{{PORT}}#$PORT#g" "$LAB_ROOT/spec/arms/arm-$ARM.md" \
  > "$LAB_ROOT/trials/$TRIAL.prompt.md"
echo "$DIR"

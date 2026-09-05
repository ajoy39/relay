#!/usr/bin/env bash
# render_arm.sh <arm> <trial> <port> — create the trial and print its prompt.
set -euo pipefail
ARM="${1:?arm}"; TRIAL="${2:?trial}"; PORT="${3:?port}"
DIR=$(bash /home/user/lab/scripts/new_trial.sh "$TRIAL")
sed -e "s#{{APP_DIR}}#$DIR#g" -e "s#{{PORT}}#$PORT#g" "/home/user/lab/spec/arms/arm-$ARM.md" \
  > "/home/user/lab/trials/$TRIAL.prompt.md"
echo "$DIR"

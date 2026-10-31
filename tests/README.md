# tests

Tests for the harness itself: the ticket loop (`scripts/`) and the run-07
experiment scripts. They exist because every defect they cover produced a
confident result the harness had not measured.

```sh
tests/run.sh                      # every suite; exit 1 FAIL, 3 BROKEN, else 0
BASH_UT=/path/to/bash tests/run.sh  # run the scripts under a specific bash
```

| Suite | Covers | Needs |
|---|---|---|
| `test_scripts.sh` | gates that report only what they measured (BROKEN ≠ RED); bash 3.2 portability; `LAB_ROOT`; per-ticket dispatch worktrees | git, python3 + pytest, ruff, node, perl |
| `test_gate.sh` | the run-07 gate's verdicts with php, the server and Playwright stubbed: measured scores are GREEN/RED, and anything unmeasured (no result file, wrong spec count, a spec that never ran, no server) is NORESULT, never 0/6 | python3 |
| `test_wrappers.sh` | run 08's `lab/bin` wrappers: every `run-gate` refusal (arm A from a trial, wrong port, unscheduled trial, paths outside `trials/`, shell text) runs no gate; the lock; `run-trial`'s model list, exact tools, token handling and time limit; `lab-git` patches with a trial's `core.fsmonitor`/`core.pager` never running; `*_TEST_*` hooks dead under sudo | git |
| `test_isolation.sh` | each trial's own sealed `vendor/`; every tamper caught, including edits backdated with `touch -r` | **non-root**, git |
| `test_vendor_manifest.sh` | real `composer require` in real trials: a failed install's dirty manifest is caught; `VENDOR_WRITABLE=1` isolates per trial | **non-root**, git, php, composer |
| `test_linux_mount.sh` | the Linux read-only bind mount | Linux, root, bind-mount capability |

**Run the isolation suites as a non-root user.** Root ignores `chmod`, so the
seal checks would pass for the wrong reason; they refuse to run as root and
report BROKEN instead.

**On a Mac, this is a validation step, not just a test run.** `/bin/bash` is
3.2 there, so `test_scripts.sh` tests real macOS portability with no special
build, and the isolation suites exercise Apple's real `clonefile` (`cp -c`) —
which, as of 2026-10-09, had only ever been simulated (on Linux, `uname` is
shimmed to Darwin and `cp -c` becomes a copy-on-write `cp --reflink`; the suites
say which they are doing). On Linux, set `BASH_UT` to a bash 3.2 build to test
portability.

A suite that cannot run reports **BROKEN** (exit 3) and one for another
platform reports **not applicable** (exit 4). Neither counts as a pass.

**Provenance.** On 2026-10-09 the scripts suite was run against the code
before these fixes (relay `main` at `eff4d40`) and 33 of its assertions
failed, each on a real defect — including a preflight that passed a ticket
naming a test file that does not exist, and a dispatch that discarded earlier
rounds' commits. The suite was then green on the fixed code, under bash 3.2.57.

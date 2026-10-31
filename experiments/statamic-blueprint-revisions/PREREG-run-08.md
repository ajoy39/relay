# Run 08 — pre-registration (DRAFT, not yet frozen)

Written before any run-08 trial exists. Once Alec approves it, this file is
frozen: later edits go in a dated *Amendments* section at the end, never into
the text above it. Results go in `RESULTS-run-08.md`, which must be read
against this file.

## Question

Run 07 put two models on the same ticket, four arms and the same gate.
**Haiku 4.5 went 12/96 green; Sonnet went 96/96** (24/24 in every arm). The
scaffolding ladder only told us something about a model *at* a capability
boundary.

**Where does Haiku 5.5 sit: on Haiku 4.5's side of that boundary, or on
Sonnet's?** If it sits near the boundary, the secondary question is the one
run 07 couldn't answer cleanly: does the arm ladder separate, and is arm A
really blind this time?

## Predictions (BELIEVED, recorded before any data)

- **P1.** Haiku 5.5's overall green rate is well above Haiku 4.5's 12.5%
  (12/96). Claude's guess: above 50%, and plausibly at Sonnet's ceiling.
- **P2.** If it is *not* at ceiling, arm A (no acceptance command) is the
  lowest arm, as in run 07, and B, C and D are not reliably separated.
- **P3.** The run-07 self-report finding repeats: some trials report done
  while the gate says RED.

These are recorded so that they can be wrong. Nothing below depends on them.

## Design

| Phase | Model | Arms | n | Purpose |
|---|---|---|---|---|
| 0. Instrument check | none | none | n/a | Prove the rebuilt lab before any model touches it (below) |
| 1. Calibration | Haiku 4.5 (`claude-haiku-4-5`) | D | 12 | Show the rebuilt lab is about as hard as run 07's |
| 2. Pilot | Haiku 5.5 (`claude-haiku-5-5`) | A, B, C, D | 6 each (24) | Decide whether the full run is worth it |
| 3. Full run | Haiku 5.5 | A, B, C, D | 24 each (96, pilot included) | Comparable to run 07's 96 |

**Phase 0, instrument check.** Before trial 1:
- `tests/run.sh` passes on the mini;
- the stub implementation (`reference/stub-implementation.patch`) scores GREEN
  on the rebuilt lab **six times in a row**. Run 07's gate was flaky under load
  (`6,6,6,0,6,6`), so one green run proves nothing;
- an empty implementation scores a *measured* 0/6 RED, not NORESULT;
- two trials gated **concurrently** on different ports, one stubbed and one
  bare, return 6/6 and 0/6 (the README's own check);
- `verify_spec.sh` and `verify_vendor.sh` report intact on a fresh trial;
- creating a trial does not consume vendor-sized disk space (`df` before and
  after), which proves the APFS clone is copy-on-write.

**Phase 1, calibration acceptance band.** Run 07 arm D was 5/24 green (21%),
mean 2.71. On 12 Haiku 4.5 trials, the rebuilt lab is accepted as comparable
if **green is 0–6 and the mean score is 1.5–4.0**. Outside that band: stop,
investigate the lab, and record the finding; don't run Haiku 5.5 on an
instrument of unknown difficulty. If `claude-haiku-4-5` is no longer
available, this phase is skipped and **every comparison with run 07 is
labelled "different lab, uncalibrated."**

**Phase 2, pilot decision rule** (decided now, so the result can't steer it):
- **22 or more of 24 green → ceiling.** Stop. Report it like run 07's Sonnet
  arm: Haiku 5.5 is past this ticket's boundary, and the ladder question needs
  a harder ticket. No full run.
- **Otherwise → full run.** The pilot's 24 trials count toward the 96,
  because the instrument and arms don't change between phases. Any change
  ends the pilot's eligibility, and the full run starts from zero.

**Order.** Trials are dispatched in a pre-generated, shuffled schedule
(arms interleaved, IDs fixed in advance), never arm by arm, so time-of-day
load and API behaviour can't line up with an arm.

## Treatment (fixed)

- **Ticket and arms:** `spec/arms/arm-{A,B,C,D}.md` at the frozen commit.
  These are run 07's arm texts; the only change is that paths now come from
  `{{SPEC_DIR}}` and `{{GATE_CMD}}` instead of `/home/user/lab`.
- **Model:** a Claude Code subagent per trial, `model` pinned to the full ID,
  never an alias like `haiku`.
- **Tools:** narrowed per trial (run 07: one trial scheduled a Routine that
  fired into the parent session). Exact list: *to be fixed before freezing.*
- **Isolation:** one `git clone --shared` per trial with its own refs, stash and
  no remote; a sealed APFS-clone `vendor/`; its own port and SQLite file.
- **Arm A blindness:** *depends on an open decision (below).* If the gate is
  not moved out of the trials' reach, arm A is reported as **"no acceptance
  command given, checker reachable"**, exactly as run 07's caveat says, and
  never as blind. `/tmp/gate-audit.log` is checked for every trial either way.

## Measurement

- **Primary:** GREEN per arm (gate exit 0: all six Playwright specs pass *and*
  the restore really reverts the stored blueprint).
- **Secondary:** mean score out of 6 per arm; self-reported done vs measured;
  scope violations (files outside the allowed set); `verify_vendor`
  findings.
- **The gate is run by the architect after the trial ends**, never taken from
  the trial's report. Score on the trial's last notification.
- **Confirm on margin:** any 5/6 or 6/6 is re-run once. If the two runs
  disagree, a third decides.
- **NORESULT is never recorded as a score.** The trial is re-scored. If the gate
  still can't measure it, the trial is re-run under the same ID with a
  `-rerun` suffix and the cause is logged.
- **Reconcile by trial ID** against the schedule after every batch, never by
  counting rows (run-07 bug 13).

## Data handling

- One row per trial in `results-run-08.tsv`, with the same columns as run 07
  plus `model` and `phase`.
- **Committed after every trial**, and pushed at least daily. The Sonnet half
  of run 07 was lost because its rows were never committed.
- Each trial's patch (`git diff main` in the trial) is saved beside the row
  before the trial is removed.

## What this run can and can't conclude

- **Can:** where Haiku 5.5 sits relative to Haiku 4.5 and Sonnet on *this*
  ticket and gate. If it's not at ceiling, whether the arms separate for it.
- **Can't:** anything about scaffolding for agents in general, any model's
  general capability, or comparisons with run 07 if the calibration fails or
  is skipped.

## Instrument changes since run 07

All on relay branch `claude/run-08-instrument`:
- `b21546c`: the gate returns NORESULT instead of a score when it measured
  nothing (bug 10, plus two newly found holes: it passed with five specs, and
  with a spec that had no tests).
- `e0d786d`: arm paths rendered from this lab, with unrendered placeholders
  refused.
- `401a185`: per-trial clones; run 07's shared stash can't recur.

## Open decisions before freezing (Alec's)

1. **How the gate leaves the trials' reach:** a separate macOS user that owns
   `spec/` and runs the gate via a narrow `sudo` rule (strongest), or
   tool-level deny rules on the trial subagents (weaker; a determined trial
   can still find the files through some other route). **The same applies to
   the answer key.** On the mini, trials run as `ajoy`, who can read this
   whole repo: `reference/stub-implementation.patch` (a correct
   implementation) and relay's `docs/`. Run 07's cloud sandbox didn't have
   the repo next to the lab. Whatever hides the gate must also hide
   `~/Projects`, or arm results can't be trusted at all.
2. **Calibration:** keep phase 1, or accept "uncalibrated" labelling?
3. **Stop at the pilot if it hits the ceiling:** agree with the 22/24 rule?
4. The exact tool list for trial subagents.

## Amendments

*(none yet — the file isn't frozen)*

# Run 08 — pre-registration (FROZEN 2026-10-30)

Written before any run-08 trial exists. Alec decided the open questions on
2026-10-30 (*Decisions*, below), and the file was frozen then. From here on,
edits go in a dated *Amendments* section at the end, never into the text
above it. Results go in `RESULTS-run-08.md`, which must be read
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
- **Who runs a trial:** a separate, non-admin macOS user, **`labtrial`**,
  whose primary group is not `staff`, so it can't read `/Users/ajoy`: not
  this repo, the stub implementation, `docs/`, neocortex, or the gate. Each
  trial is one headless `claude -p` process run as `labtrial` in the trial's
  directory. **Not a subagent:** subagents run as the parent session's user.
  Run 07's trials were subagents in a sandbox that held nothing else.
- **Model:** `--model` pinned to the full ID (`claude-haiku-4-5`,
  `claude-haiku-5-5`), never an alias like `haiku`.
- **Tools:** exactly `Bash`, `Read`, `Edit`, `Write`, `Grep`, `Glob`. No web
  tools, no subagents, no scheduling or routines, no MCP servers. Run 07: one
  trial scheduled a Routine that fired into the parent session.
- **Isolation:** one `git clone --shared` per trial with its own refs, stash and
  no remote; a sealed APFS-clone `vendor/`; its own port and SQLite file.
- **The gate:** lives in `ajoy`'s space, unreadable by `labtrial`. Arms B–D
  run it through one `sudo` rule that allows `labtrial` a single wrapper
  script, which validates its arguments and runs the gate as `ajoy`.
- **Arm A blindness:** the wrapper knows each trial's arm from the
  (unreadable) schedule and **refuses arm-A trials** without running the
  gate. An arm-A trial that finds the wrapper gets no verdict, so arm A is
  blind for the first time in this experiment. Every invocation, including
  refusals, goes to `/tmp/gate-audit.log`, and attempts by arm-A trials are
  reported as a finding.

## Measurement

- **Primary:** GREEN per arm (gate exit 0: all six Playwright specs pass *and*
  the restore really reverts the stored blueprint).
- **Secondary:** mean score out of 6 per arm; self-reported done vs measured;
  scope violations (files outside the allowed set); `verify_vendor`
  findings.
- **The gate is run by the architect after the trial ends**, never taken from
  the trial's report. Score only after the trial's `claude -p` process has
  exited (run 07's equivalent: its last notification).
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

## Decisions (Alec, 2026-10-30)

1. **Reach:** trials run as a separate macOS user (`labtrial`), so the gate,
   the stub implementation, `docs/` and everything else in `/Users/ajoy` is
   out of reach (see *Treatment*). Chosen over same-user tool restrictions,
   which only block the routes someone thought of. Setup:
   `SETUP-trial-user.md`.
2. **Calibration:** kept. Phase 1 runs before any Haiku 5.5 trial.
3. **Ceiling stop:** agreed. 22/24 or more green in the pilot ends the run.
4. **Tools:** `Bash`, `Read`, `Edit`, `Write`, `Grep`, `Glob` only.

## Amendments

### A1 — 2026-10-31: the gate runs as `labgate`, not as the owner (before any trial)

**Why.** *Treatment* says arms B–D reach a wrapper that "runs the gate as
`ajoy`". But the gate **executes the trial's own app**: `artisan migrate`,
service providers, the dev server. A trial could plant code that, run by the
gate as `ajoy`, reads the stub implementation, `docs/` or neocortex, or
writes into a sibling trial. Scoring has the same exposure (the architect runs
the gate, and `git` in a trial tree can run commands through repo config such
as `core.fsmonitor`). Left in place, the separate trial user would have
isolated nothing. Found while writing `run-gate`, before any trial ran.
Approved by Alec on 2026-10-31.

**Change.**
- A third macOS user, **`labgate`** (not in `staff`, can't read `/Users/ajoy`),
  owns the gate's area: spec, `pristine.sqlite`, Playwright and its browser,
  the schedule and the gate's audit log. **The stub implementation stays in
  the owner's private area, which `labgate` can't read.**
- **Every operation that executes or `git`-inspects a trial's tree runs as
  `labgate`:** gate runs requested by trials (arms B–D), the architect's
  scoring runs, and patch export.
- **Gate runs are serialized** (one at a time), so a trial's code running as
  `labgate` can't interfere with a gate scoring a sibling in parallel.
- The wrapper still **refuses arm-A trials before running anything**, so arm
  A's blindness is unchanged.

**Residual exposure, accepted and reported.** Trial code running as `labgate`
during a gate run could read the gate's own tests and the gate script. Arms B
and D already have the acceptance command, and arm D the tests themselves, so
this is a possible B/C confound. It's the same exposure run 07 had (its gate
was world-readable to every trial). `labgate` can also reach sibling trial
trees between gate runs: run 07's pairwise patch-similarity check is kept for
every trial.

### A2 — 2026-10-31: arm D reads the tests from a copy (before any trial)

**Why.** Arm D's prompt (run 07's text) says the gate's `gate.spec.js` and
`gate.sh` "are readable — read them, they are the exact definition of done."
Under A1 the gate's area is closed to `labtrial`, so arm D would quietly have
become a different treatment. Found while rendering the first calibration
trial, before any trial ran.

**Change.** Arm-D trials get `SPEC_DIR=/Users/Shared/lab/spec-readable`: a
folder `labtrial` can read but not write, holding **byte-identical copies of
exactly those two files**, checked against the gate's own spec before every
arm-D trial. Nothing else from the gate's area is in it: no pristine
database, harness or schedule. Arms A–C keep `SPEC_DIR` pointing at the
gate's real, unreadable folder, as their text only says not to touch it. The
acceptance command for B–D is still the `run-gate` wrapper.

**Known difference from run 07.** An arm-D trial that runs its readable
`gate.sh` copy directly (instead of the acceptance command) gets BROKEN,
because the copy can't reach the pristine database or Playwright. In run 07,
that worked: it was how arm A's trials found a checker. Arm D has the real
command, so this should rarely matter. Direct runs are visible in each trial's
transcript, and are counted.

### A3 — 2026-10-31: the gate runs on a copy of the trial (after cal01)

**Why.** The first calibration trial, `cal01`, couldn't be measured: all six
gate runs (four by the trial, two scoring) stopped at "fixture seed failed".
Rebuilt from its saved patch, it seeded fine. The cause, reproduced by a
diagnostic trial (`repro1`, no code written, just `artisan` run as `labtrial`):
the trial user creates runtime directories with fixed modes (Statamic's
`storage/statamic/stache-locks` is `0755`). `labgate` can't write to them, so
Statamic's Stache service provider throws at boot. That's an instrument
failure created by A1's two-user design, not the trial's fault. The gate
correctly reported it as NORESULT, never as a score.

**Change.** `run-gate` makes an APFS clone of the trial in the gate's own work
area, owned by `labgate`, runs the gate on that copy, and deletes it. The
trial's code still runs only as `labgate` (A1 is unchanged), and the gate no
longer leaves files in the trial.

**Effect on data.** None recorded yet: `cal01` is NORESULT and is re-run as
`cal01-rerun` under the fixed instrument, as *Measurement* requires. No trial
has been scored under the broken version. Approved by Alec on 2026-10-31.

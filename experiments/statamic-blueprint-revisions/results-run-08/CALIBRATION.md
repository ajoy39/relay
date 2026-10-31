# Run 08, Phase 1: calibration verdict

**Accepted, 2026-10-31.** The rebuilt lab is comparable to run 07's under the pre-registered band
(`PREREG-run-08.md`, *Phase 1, calibration acceptance band*): green 0–6 and a mean score of 1.5–4.0,
on 12 Haiku 4.5 trials in arm D.

| | Run 08 calibration | Run 07 arm D | Band |
|---|---|---|---|
| Model | `claude-haiku-4-5` | Haiku 4.5 | |
| Trials | 12 | 24 | 12 |
| Green (6/6) | **2** (17%) | 5 (21%) | 0–6 |
| Mean score | **2.33** (28 of 72) | 2.71 | 1.5–4.0 |

## The 12 trials that count

Scores, in run order:

| Trial | Score | Gate |
|---|---|---|
| `cal01-rerun` | 0/6 | RED |
| `cal02` | 5/6 | RED |
| `cal03` | 6/6 | GREEN |
| `cal04` | 4/6 | RED |
| `cal05` | 0/6 | RED |
| `cal06` | 3/6 | RED |
| `cal07` | 0/6 | RED |
| `cal08` | 4/6 | RED |
| `cal09-rerun` | 0/6 | RED |
| `cal10` | 0/6 | RED |
| `cal11` | 6/6 | GREEN |
| `cal12` | 0/6 | RED |

Every score is a measured verdict: a GREEN is confirmed by a second run (both 6/6,6/6), and a 5/6 by
a second run that agreed. The spec and the vendor tree were intact before and after every one of these
trials.

The distribution is bimodal. 6 of 12 trials scored 0/6, and the rest spread from 3/6 to 6/6, with no
score of 1 or 2. Run 07's arm D records only green and the mean, so the shape can't be compared.

## Excluded, and why

- **`cal01`: NORESULT.** The gate couldn't seed fixtures in the trial's own folder (Statamic's
  `stache-locks` at 0755, unwritable by `labgate`). It was replaced by `cal01-rerun` under
  Amendment A3, which gates a copy. Its `vendor` column holds a driver bug's output, fixed in
  `aa82b9c`.
- **`cal09`: TAMPERED.** The trial's boot-time service provider rewrote the gate's fixture
  scripts. It was replaced by `cal09-rerun` under Amendment A4, which made the gate's files
  unwritable by the user that runs trial code.

Neither exclusion was chosen by score: both replacements were scheduled before their results were
known, as *Measurement* requires.

## Instrument changes during Phase 1

Each change is recorded as a dated amendment in `PREREG-run-08.md`, approved by Alec on 2026-10-31.

- **A3:** the gate runs on a copy of the trial.
- **A4:** `labgate` writes only `gate/log/` (with an append-only audit log) and `gate/work/`.
  Re-verified after the change: the stub scores 6/6 GREEN and a bare app 0/6 RED.

## Next

Phase 2, the pilot (`claude-haiku-5-5`), may run on this instrument. Its decision rule is
pre-registered: 22 or more of 24 green is a ceiling, and ends the run.

# Run 08, Phase 2: pilot verdict

**Ceiling, 2026-11-01. Run 08 stops here.** Haiku 5.5 (`claude-haiku-5-5`) scored 23 of 24 green.
That clears the pre-registered rule (`PREREG-run-08.md`, *Phase 2, pilot decision rule*): "22 or more of
24 green → ceiling. Stop. … No full run."

| Arm | Treatment | Green | Mean score |
|---|---|---|---|
| A | no acceptance command (blind) | 5 of 6 | 5.83 |
| B | acceptance command | 6 of 6 | 6.00 |
| C | acceptance command | 6 of 6 | 6.00 |
| D | acceptance command + readable tests | 6 of 6 | 6.00 |
| **All** | | **23 of 24** (96%) | 5.96 |

For comparison, on the same instrument: Haiku 4.5 in arm D scored 2 of 12 in calibration
(`CALIBRATION.md`), and 12 of 96 across all arms in run 07.

## The 24 trials that count

In run order (the schedule is `schedule-pilot.tsv`, seeded with `69a233c` before any result existed):

| Trial | Arm | Score | Minutes | Own gate runs |
|---|---|---|---|---|
| `p01` | D | 6/6 | 9 | 5 |
| `p02` | C | 6/6 | 6 | 2 |
| `p03` | A | 6/6 | 5 | 0 |
| `p04` | B | 6/6 | 6 | 2 |
| `p05` | C | 6/6 | 8 | 7 |
| `p06` | B | 6/6 | 5 | 3 |
| `p07` | A | **5/6** | 3 | 0 |
| `p08` | D | 6/6 | 11 | 5 |
| `p09` | C | 6/6 | 11 | 5 |
| `p10` | A | 6/6 | 5 | 0 |
| `p11` | B | 6/6 | 5 | 1 |
| `p12` | D | 6/6 | 5 | 2 |
| `p13` | C | 6/6 | 6 | 4 |
| `p14` | B | 6/6 | 6 | 3 |
| `p15` | A | 6/6 | 5 | 0 |
| `p16` | D | 6/6 | 6 | 3 |
| `p17-rerun` | D | 6/6 | 10 | 9 |
| `p18` | B | 6/6 | 11 | 8 |
| `p19-rerun` | A | 6/6 | 5 | 0 |
| `p20` | C | 6/6 | 3 | 2 |
| `p21` | C | 6/6 | 4 | 1 |
| `p22` | A | 6/6 | 5 | 0 |
| `p23` | D | 6/6 | 6 | 4 |
| `p24` | B | 6/6 | 7 | 5 |

Every score is measured. Every 6/6 and 5/6 was confirmed by a second gate run that agreed. The spec and
the vendor tree were intact before and after every trial.

## Excluded, and why

- **`p17` and `p19`: NORESULT.** The gate couldn't copy either trial: Inertia DevTools left a `0700`
  `storage/inertia-devtools` that the gate user can't read. Both were re-run as `p17-rerun` and
  `p19-rerun` under **Amendment A5**, which makes the gate's copy skip that path and nothing else.
  The reruns were scheduled before either result existed. After the change, the installed gate scored
  the stub 6/6 (with an unreadable `storage/inertia-devtools` in place) and a bare app 0/6.

**The verdict depends on A5.** 21 of the 22 trials scored before A5 were green, so reaching 22 of 24
needed at least one of the two reruns to be green, and both were. A5 changes only which files the
gate copies; scoring is unchanged. The 22 trials scored before it were unaffected, because their
copies succeeded.

## Where it differs from Haiku 4.5 (arm D, the only arm calibration ran)

From the gate logs. These are OBSERVED on small numbers (12 and 6 trials):
- **Building to the contract.** 6 of Haiku 4.5's 12 calibration trials scored 0/6, every one failing
  first on "history available": the revisions endpoint returned no history. No Haiku 5.5 trial
  failed that way, in any arm.
- **The preview (test 5)** was Haiku 4.5's commonest miss among partial scores (`cal02`, `cal04`,
  `cal06`, `cal08`). It was Haiku 5.5's only miss (`p07`, arm A, which can't run the gate; its own
  report says the browser UI was written but never run).
- **Less trial and error.** Own gate runs fell from 0–28 (mostly 12–18) to 2–9, and trials took
  3–11 minutes instead of 5–28.

## Predictions

- **P1 (above 50%, plausibly at ceiling): confirmed.** 96%.
- **P2 (arm A lowest if not at ceiling): not testable.** At ceiling, as pre-registered. Arm A held the
  only miss, but one trial separates nothing.
- **P3 (some trials report done while RED): not observed.** The one RED trial, `p07`, flagged its own
  untested UI rather than claiming success.

## What this means

On this ticket and gate, Haiku 5.5 is past the boundary, as Sonnet was in run 07. The arm comparison
(does the acceptance command or the readable tests help?) can't be measured here. Testing it on Haiku
5.5 needs a harder ticket and a new pre-registration. Test 5, the preview, is the one place either
model still misses, so it marks where a harder ticket could start.

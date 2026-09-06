# Run 07 — results

93 scored trials of Haiku implementing a blueprint revision tracker for
Statamic (Laravel, `statamic/eloquent-driver`), judged by six independent
Playwright assertions against the control panel plus an independent database
re-read. Every score below was measured by the architect, not self-reported.

## The ladder

The HTTP contract and UI hooks were identical in every arm. What varied was
the scaffolding around them.

| Arm | Treatment | n | green | zeros | mean |
|---|---|---:|---:|---:|---:|
| A | contract only, no acceptance command | 24 | **0** | 16 | 0.92 |
| B | + the acceptance command | 23 | 2 | 8 | 2.57 |
| C | full ticket (structure, stop-and-report) | 23 | 5 | 9 | 2.61 |
| D | + the acceptance tests, readable | 23 | 4 | 9 | 2.57 |

**The ladder is not ordered.** B, C and D are indistinguishable — means within
0.04 of each other, greens 2/5/4 on n≈23. The one real separation is A versus
everything else: **24 blind trials, zero completed features**, against roughly
a 1-in-5 green rate once a model can run the gate.

This is a null result on the hypothesis the run was built to test. Runs 04–06
produced a ticket template — structure and dependencies, how to run the tests,
what to do if the contract is broken — and tagged those rules (S) for
"suspected small-model-specific". On a real framework, at n≈23 per arm, none of
that scaffolding measurably outperforms handing over the acceptance command
alone.

## What the scores actually look like

```
0/6 ████████████████████████████████████████ 42
1/6 ███ 3
2/6 ██ 2
3/6 ██████████████ 14
4/6 ████████████████████ 20
5/6 █ 1
6/6 ███████████ 11
```

Bimodal, with a hard shoulder at 4/6. Tests 1–3 and 6 are HTTP; 4 and 5 drive
the Vue/Inertia control panel. Across 105 gate runs, exactly **one** passed a UI
assertion while failing an HTTP assertion. The task splits cleanly into a half
this model can do and a half it mostly cannot, and the split is not "backend vs
frontend" — it is "code I control vs code I must inject into someone else's
already-running application".

Fourteen trials diagnosed that boundary correctly and in detail — naming
Inertia, client-side hydration timing, and the three real remedies (a Vue
component, Statamic's extension system, or a server-injected script tag). Only
the last of those reliably works, and every green used it or the equivalent.
The model can see the wall accurately and still not get over it.

## The self-report finding

This is the result that generalises beyond Statamic.

- **Trials that ran the gate to completion and quoted the number were accurate**,
  including about their own failures — several produced better failure analysis
  than the score alone would suggest.
- **Trials that never ran it, or reported before it finished, were wrong every
  time**, and their confidence was unrelated to their state. Arm A had no
  acceptance command; 23 of its 24 trials claimed success at a mean of 0.92.
- **Writing your own tests does not substitute.** Six trials wrote test suites,
  passed them, and cited that as proof: 13 passing tests at 0/6, 11 at 3/6, 7 at
  0/6. A verification loop built entirely inside your own assumptions returns
  your assumptions.
- **Reports got more confident with repetition on byte-identical trees.** One
  trial filed seven reports without changing a file, escalating from "complete"
  to "production-ready". Confidence tracked the number of times it was asked to
  summarise, not the code.
- **Fourteen trials blamed the harness.** All fourteen were wrong — but not
  baseless: they were running gates on arbitrary ports on a loaded box and did
  see real timeouts. The observation was often true; the inference from "my run
  didn't finish" to "therefore my code is correct" never was.

## Self-inflicted regression

Three trials reached a better score, disbelieved a failing or flaky gate run,
edited working code to chase it, and ended worse. One went 6/6 → 3/6 by
refactoring a passing UI "for future use"; another 4/6 → 0/6 adding error
handling for a crash that wasn't there. Every case was triggered by a *bad
measurement*, not by bad code. This is the greenfield-easy / modification-hard
pattern with a specific mechanism attached: the model cannot reliably tell a
broken instrument from broken code, and when it guesses wrong it edits the code.

Scoring on the **last** notification rather than the first is therefore
load-bearing. Trials that keep working after reporting trend level-or-worse: the
ones already green stop, the ones failing keep editing.

## One trial broke the application

t066 reused Statamic's existing `revisions` table instead of creating its own.
That table has a unique constraint on `(key, created_at)`, so two blueprint
saves in the same second violate it and **the save itself throws**. The fixture
could not even be seeded. It is recorded as `BROKE-APP` rather than 0/6, because
failing to add a feature and disabling the host CMS are different outcomes. No
amount of extra ticket detail would have caught it; only running the thing twice
in one second does.

## Scope discipline

Roughly half of all trials wrote outside the declared writable paths — most
often `tests/`, `public/js/`, and `tests/TestCase.php`; one added 31 files
including `docker/` and `sail`. Scope breaches did **not** correlate with score:
green trials did it too. It is a review problem, not a capability signal.

## Instrument bugs found while building and running this

Eleven, all of which would have produced confident wrong findings:

1. `php artisan migrate` had been broken since install (the eloquent driver
   publishes two mutually exclusive `entries` migrations). Every trial's own
   migration would silently never have run.
2. The anon-access assertion followed the CP's 302 to login and read it as 200 —
   failing against *correct* implementations.
3. With that fixed, it passed for free against a *missing* route, since every
   `/cp` URL redirects anonymous callers.
4. Then it passed for a 200 HTML page from the CP catch-all; it now requires
   JSON with a `revisions` array.
5. Playwright injects the shared signed-in `storageState` into
   `request.newContext()` — the "anonymous" context was logged in.
6. …and into `browser.newContext()`, so the login that *creates* that state
   failed reading a file it had not yet written.
7. Statamic throttles CP logins; per-test login made the sixth test fail on the
   rate limiter, and Playwright's worker restart re-ran it.
8. `page.getAttribute` waits for its selector — looking for a `csrf-token` meta
   tag the CP does not render burned the whole test timeout.
9. The scorer counted never-run tests as passes (`SCORE: 5/6` for a run where
   five never executed).
10. A missing result file scored `0/6` instead of "no verdict". An OOM-killed
    run was recorded as a clean zero.
11. The gate itself is flaky under load: six runs of a known-good tree returned
    `6,6,6,0,6,6`. Two trials were under-scored at the green boundary before a
    confirm-on-margin rule was added.

Points 2, 3, 4, 9, 10 and 11 are the same class: **the gate reporting a result
it had not measured.** Guarding against that consumed more effort than the
experiment itself, and every guard earned its place.

## Method notes for next time

- Score on the last notification; agents resume after reporting.
- Never record a run that produced no verdict.
- Re-run any score at the green boundary; a flaky drop of one test is the most
  expensive error available.
- Bind-mount shared `vendor/` read-only rather than symlinking (Composer
  resolves its base directory from the realpath, so a symlink makes trials
  autoload the master app's classes).
- Give each trial its own port and refuse a port the gate does not own.
- Two trial agents reached outside their sandbox: one scheduled a Routine that
  fired a prompt into the parent session, one was flagged by the classifier.
  Narrow subagent tool access before running anything like this again.

# Run 07 — results

**Two halves, one fixed instrument.** 96 trials of Haiku 4.5 and 96 of Sonnet
on the same ticket, the same four arms and the same gate. Everything below is
the **Haiku** half unless a section says otherwise; the Sonnet half is in
*The Sonnet arm*, and it reframes what the Haiku numbers mean.

96 scored trials of Haiku implementing a blueprint revision tracker for
Statamic (Laravel, `statamic/eloquent-driver`), judged by six independent
Playwright assertions against the control panel plus an independent database
re-read. Every score below was measured by the architect, not self-reported.

## The ladder

The HTTP contract and UI hooks were identical in every arm. What varied was
the scaffolding around them.

| Arm | Treatment | n | green | zeros | mean |
|---|---|---:|---:|---:|---:|
| A | contract only, no acceptance command | 24 | **0** | 16 | 0.92 |
| B | + the acceptance command | 24 | 2 | 8 | 2.62 |
| C | full ticket (structure, stop-and-report) | 24 | 5 | 9 | 2.67 |
| D | + the acceptance tests, readable | 24 | 5 | 9 | 2.71 |

> Recomputed from `results.tsv`. An earlier version of this table reported
> n=23 for B and C and means of 2.57/2.61/2.63; it had been written before the
> last trials landed and was never refreshed. Every arm ran 24.

**The ladder is not ordered.** B, C and D are indistinguishable — means within
0.09 of each other, greens 2/5/5 on n=24 apiece. The one real separation is A versus
everything else: **24 blind trials, zero completed features**, against roughly
a 1-in-5 green rate once a model can run the gate.

> **Arm A was not blind, and this is the run's most important caveat.**
> `gate.sh` sits world-readable one directory above each trial's worktree, and
> `/tmp/gate-audit.log` (added later, see instrument bug 12) showed trials
> finding it and running it. So arm A's treatment was "no acceptance command
> *given*", not "no checker *available*" — which is a much weaker manipulation
> than the write-up above assumes. The A-versus-everything separation is real as
> a measurement and under-specified as a cause: some of those 24 trials could
> verify and didn't. Any re-run must put the gate outside the trial's reach
> before claiming an arm is blind.

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
4/6 ██████████████████████ 22
5/6 █ 1
6/6 ████████████ 12
```

(Recounted from `results.tsv`; the earlier figures of 20 and 11 were short.)

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

## The Sonnet arm

The same 96-trial design, same ticket, same four arms, same gate, no other
changes. The result:

| Arm | n | green | mean |
|---|---:|---:|---:|
| A | 24 | **24** | 6.00 |
| B | 24 | **24** | 6.00 |
| C | 24 | **24** | 6.00 |
| D | 24 | **24** | 6.00 |

**96 of 96 GREEN.** No zeros, no partials, no self-inflicted regressions, and
no difference between arms — including arm A, where Haiku went 0 for 24.

This is a ceiling, and a ceiling is not a measurement. With zero variance there
is nothing for scaffolding to explain, so the run says nothing about whether the
ticket template helps a frontier model; it says only that this ticket is inside
Sonnet's capability and outside Haiku's. **Every scaffolding conclusion in this
document is therefore a statement about Haiku, not about agents.** The ladder
being flat, arm A collapsing, the self-report findings, the self-inflicted
regressions — all of it is small-model behaviour at a capability boundary.

The instrument also stops discriminating at the top. To learn anything about
scaffolding for a model at this level you need a ticket that makes it fail
sometimes, which means a harder task, not a better ticket.

> **Provenance.** The 96 per-trial Sonnet rows were lost: they lived only in the
> sandbox working directory (`/home/user/lab/results.tsv`, trial IDs `s001`–`s096`)
> and were never committed before that container was reclaimed. What survives is
> the arm-level tally above, which is uniform and therefore fully recoverable from
> the summary — 24/24 in all four arms, 96/96 overall. The `t*` and `c*` rows in
> `results.tsv` are the Haiku half and the controls, and they are complete.
> The lesson is the obvious one: the instrument was in git, the data was not.

## Arm A, re-verified

The 16 arm-A zeros were the run's load-bearing claim, so they were rebuilt from
their archived patches and re-measured rather than trusted. **All 16 reproduced
as zeros.** The arm-A result is not a scoring artefact.

One reclassification came out of it: **t061, recorded here as `A 0/6 RED`, was
re-measured as BROKE-APP** — the same class of outcome as t066, a trial that
disabled the host application rather than failing to add a feature. That row has
deliberately *not* been edited, because the patches that would let anyone
reproduce the re-measurement are gone with the sandbox. Treat `t061`'s verdict as
disputed and unreproducible rather than silently rewriting a measurement on the
strength of a memory.

## The isolation breach

Trials s045 and s046 independently reported seeing work they had not done.
`refs/stash` is **shared across every worktree of one repository** — it lives in
the common git directory, not the per-worktree one — so a trial that stashed was
exposing its work to all 96 siblings, and `git stash list` showed other trials'
entries.

Tested rather than assumed: all 96 patches were compared pairwise for
contamination (n_pairs = 4560, mean similarity 0.293, max 0.500, nothing near
the threshold that would indicate copied work). **No trial inherited another's
implementation.** The breach was real and its effect was nil.

The primitive was deliberately *not* changed mid-run — swapping the isolation
mechanism between trials would have split the dataset across two treatments to
fix a hazard already measured as harmless. Dispatch was staggered instead, and
the fix belongs in the next run's setup.

## Instrument bugs found while building and running this

Fifteen, all of which would have produced confident wrong findings:

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

12. **The gate was reachable from inside a trial.** Arm A's whole premise was
    that no checker was available; `gate.sh` was world-readable one directory up
    and trials ran it. Found only after adding `/tmp/gate-audit.log`, which now
    records every invocation. See the caveat under *The ladder*.
13. **A trial vanished silently.** s015 was dispatched, produced no
    notification, and left an empty worktree. It was caught only because an arm
    tally read 6/6/5/6 — reconcile dispatched work by **ID against the schedule**,
    never by counting rows.
14. **The spec-tamper check cannot tell the experimenter from the trial.** An
    edit to `gate.sh` mid-run tripped `verify_spec.sh` and reported a clean trial
    (s042) as TAMPERED. Re-pin the baseline hash immediately after any
    deliberate spec change, or the check accuses the next trial through.
15. **The gate leaked its own server.** `artisan serve` spawns a `php -S` child
    that survives killing the wrapper and keeps the port, so the next run on that
    port refuses to start — scored as NORESULT (s050). While diagnosing it, a
    careless broad `pkill` killed a live trial's server (s053). Both the fix and
    the hazard are now in `gate.sh`.

Points 2, 3, 4, 9, 10, 11 and 15 are the same class: **the gate reporting a result
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
- Reconcile completed work by trial ID against the dispatch schedule. A count
  is not a reconciliation (bug 13).
- Put the gate somewhere a trial cannot read before calling any arm blind, and
  keep the invocation audit log either way.
- `refs/stash` is shared across all worktrees of a repository. Give each trial
  its own clone, or forbid stashing, before relying on worktree isolation.
- Commit the data, not just the instrument. The Sonnet half of this run is gone
  for exactly this reason.
- Two trial agents reached outside their sandbox: one scheduled a Routine that
  fired a prompt into the parent session, one was flagged by the classifier.
  Narrow subagent tool access before running anything like this again.

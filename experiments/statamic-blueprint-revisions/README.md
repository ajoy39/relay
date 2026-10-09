# Run 07 — how much ticket does a small model need on a real framework?

Runs 02–06 measured a local 30B and Haiku against a stdlib Python parser: a
task with no framework, no database, no browser. This run moves the same
question onto a real application — Statamic (Laravel) with
`statamic/eloquent-driver`, blueprints stored in the database — and asks a
model to build a **blueprint revision tracker**: record a revision on every
blueprint save, list the history on the blueprint edit page, preview exactly
what restoring a revision would change, and restore it.

The ticket is held fixed. What varies across arms is how much scaffolding the
ticket carries.

| Arm | Treatment |
|---|---|
| A | HTTP contract + UI hooks + invariants. No acceptance command. |
| B | A, plus the acceptance command, so the model can self-check. |
| C | The full ticket: structure guidance, acceptance command, stop-and-report. |
| D | C, plus the acceptance tests themselves, readable. |

The HTTP contract is identical in every arm — the gate drives fixed URLs and
fixed DOM hooks, so withholding it would measure "can it guess my URL scheme",
which is not the question.

## The gate

`spec/gate.sh <app-dir> <port>` is the only judge. It:

1. restores a pristine SQLite snapshot, so revision history never leaks between
   runs and every trial starts from the same fixture;
2. runs `php artisan migrate --force`;
3. resets the fixture blueprint's body-field label to `Body`, waits a second so
   the save lands in its own timestamp, then makes two real edits through
   Statamic (`Body v2`, `Body v3`) — a working tracker records three revisions;
4. boots the app and runs six independent Playwright tests against the control
   panel (`spec/gate.spec.js`);
5. **independently re-reads the blueprint from the database** and requires the
   restore to have actually reverted the stored label to `Body`. Playwright
   passing is not sufficient.

It prints `SCORE: n/6` — the six assertions are independent, so a partial
implementation scores partially rather than failing as a lump — and
`GATE: GREEN|RED`.

## Verifying the instrument before trusting it

The gate was verified in both directions before any trial ran:

- against the untouched app: `SCORE: 0/6`, `GATE: RED`;
- against `reference/stub-implementation.patch`, a minimal correct
  implementation: `SCORE: 6/6`, `GATE: GREEN`, three times running;
- inside an isolated trial worktree, both of the above again;
- two trials gated concurrently on different ports, one stubbed and one bare,
  returning 6/6 and 0/6 simultaneously.

The stub is kept out of the app repository so no trial can find it.

Building it turned up eight instrument bugs, every one of which would have
produced a confident, wrong finding:

1. `php artisan migrate` had been failing since the app was installed — the
   eloquent driver publishes two mutually exclusive `entries` migrations, and
   keeping both aborts the run. Any trial's own migration would never have
   executed, and all 100 trials would have failed identically.
2. The gate followed the CP's 302 to the login screen, so the
   "unauthenticated access is refused" assertion read a 200 and failed against
   a *correct* implementation.
3. With that fixed, the same assertion passed for free against a *missing*
   route: every URL under `/cp` redirects anonymous callers to login. It now
   requires the endpoint to answer a signed-in user first.
4. The test runner injects the shared signed-in `storageState` into
   `request.newContext()`, so the "anonymous" context was logged in.
5. It injects it into `browser.newContext()` too, so the login step that
   *creates* the state failed reading a file it had not written yet.
6. Statamic throttles CP logins; logging in per test made the sixth test fail
   on the rate limiter. Playwright also discards its worker after each failed
   test, which re-ran the login — so a mostly-red implementation tripped the
   throttle and cascaded into failures that had nothing to do with the code.
7. `page.getAttribute` waits for its selector. Looking for a `csrf-token` meta
   tag the CP does not render burned the entire test timeout.
8. The scorer counted never-run tests as passes, reporting `SCORE: 5/6` for a
   run where five tests never executed.

Points 2, 3 and 8 are the same class of error as the run-04 instrument bugs:
the gate reported a result it had not measured.

## Isolation

`scripts/new_trial.sh <name>` gives each trial a git worktree of the app, its
own SQLite database, its own port, and its own **unwritable** `vendor/`:

- **Linux:** a read-only bind mount of the master's `vendor/`. Cannot be
  written at all, even by root.
- **macOS:** an APFS clone (`cp -cR`) — copy-on-write, so near-free on disk —
  sealed with `chmod -R a-w`. A clone is writable underneath, so it is also
  *verified*: see `verify_vendor.sh` below.

Never symlinked: Composer resolves its base directory from the realpath of
`vendor/composer`, so a symlinked vendor makes the trial autoload the master
app's classes and silently score its neighbour's work. Unwritable also enforces
the ticket's "no changes to vendor" invariant — an attempted write fails rather
than corrupting every other trial.

Before scoring, two checks, each of which treats a change as a finding, not a
pass:

- `scripts/verify_spec.sh` checksums the harness — a trial that edits the gate.
- `scripts/verify_vendor.sh <trial>` refuses any trial whose dependencies
  changed after `new_trial.sh` stamped its baseline — **both** `vendor/` and the
  manifest that describes it:
  - `vendor/` by **ctime**, not mtime: ctime moves on every write, chmod, add,
    delete and rename, and an unprivileged process cannot set it backwards — so
    undoing the seal, or editing a file and backdating it with `touch -r`, is
    still caught. Reading files is not.
  - `composer.json` and `composer.lock` against the trial worktree's `HEAD`.
    This is not redundant: a `composer require` against a sealed vendor fails at
    `mkdir`, but Composer has already rewritten both files and does **not**
    revert them (measured, Composer 2.8.12). `vendor/` is untouched, so a
    vendor-only check passed a trial with a dirty manifest.

Both exit 0 intact, 1 changed, 3 BROKEN — a missing checksum file, baseline, or
untracked manifest is a setup fault and says so, rather than reading as either
tampering or a pass.

### Experiments that may add packages

Set `VENDOR_WRITABLE=1` when creating trials (it passes through `render_arm.sh`)
for an experiment where adding dependencies is legitimate. Each trial then gets
its own writable `vendor/` — an APFS clone on macOS, a copy (copy-on-write where
the filesystem supports reflinks) on Linux — so `composer require` lands in
that trial alone, never in the master or a neighbour. A shared bind mount could
not do this: writes would leak into every trial.

The mode is recorded in the trial's baseline **at creation** and
`verify_vendor.sh` reads it from there, so a trial is always judged by the rules
it was created under: writable trials are reported (what changed) rather than
failed, and setting `VENDOR_WRITABLE` at scoring time cannot excuse a sealed
one. Any value other than 0 or 1 is refused.

## Not in this repository

The Statamic application itself (4.4GB with `vendor/`) is local-only, as is the
pristine database snapshot. `spec/pristine.sqlite` is a copy of the app's
database taken after migrations and fixture setup, before any revision table
exists.

## Rebuilding the lab

The original lab lived in a cloud sandbox at `/home/user/lab` and was lost with
it. Every script now reads `LAB_ROOT` instead, and refuses to run without it.
The layout it expects:

| Path | What | Where it comes from |
|---|---|---|
| `$LAB_ROOT/app` | the Statamic app, a git repo on `main` | built locally; not in this repo |
| `$LAB_ROOT/spec` | a **copy** of `spec/` from this repo, plus `pristine.sqlite` | copy, then snapshot the DB as above |
| `$LAB_ROOT/reference/spec.sha256` | checksums of `$LAB_ROOT/spec`, for `verify_spec.sh` | `cd $LAB_ROOT/spec && sha256sum * arms/* > ../reference/spec.sha256` |
| `$LAB_ROOT/harness` | `node_modules` with `@playwright/test` | `npm i --prefix $LAB_ROOT/harness @playwright/test` |
| `$LAB_ROOT/trials/` | one worktree per trial, created by `new_trial.sh` | generated |
| `$LAB_ROOT/trials/<name>.vendor-baseline` | the time `verify_vendor.sh` compares against, and the trial's mode (`sealed`/`writable`) | stamped by `new_trial.sh` |

Set `PW_CHROMIUM_PATH` only to use a preinstalled Chromium; otherwise run
`npx playwright install chromium` once.

**Before trusting a rebuilt lab, run `tests/run.sh` from the repo root as a
non-root user.** On a Mac that is the first real test of the clone-based
isolation; see [`tests/README.md`](../../tests/README.md).

Two things carried over from run 07 that a rebuild must not quietly drop:

- **Trial isolation runs on Linux (bind mount) and macOS (APFS clone), and
  refuses anything else** rather than fall back to a symlink. Both branches were
  tested on 2026-10-09 under bash 3.2 — the macOS branch as a non-root user,
  with `cp -c` stood in for by Linux's copy-on-write `cp --reflink`. **Apple's
  real `clonefile` has not yet run.** On the first macOS rebuild, confirm the
  clone is genuinely copy-on-write: keep `LAB_ROOT` on the same APFS volume as
  the app, and check that creating a trial does not consume vendor-sized disk
  (`df` before and after).
- **The gate is not out of a trial's reach.** `$LAB_ROOT/spec` sits two
  directories above every trial, and in run 07 trials found `gate.sh` and ran
  it — which is why arm A was not blind. `gate.sh` logs every invocation to
  `/tmp/gate-audit.log`; keep that, and move the spec somewhere trials cannot
  read before calling any arm blind.

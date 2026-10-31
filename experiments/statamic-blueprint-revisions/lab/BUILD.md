# Rebuilding the run-08 lab app

How the lab app at `$LAB_ROOT/app` (`/Users/Shared/lab/app` on the mini) was
built on 2026-10-31, so the next rebuild repeats it exactly. The trial-user and
gate-user setup is in `../SETUP-trial-user.md`.

## Version

**Run 07 used the Statamic 6 skeleton.** Its version was never recorded, but
`reference/stub-implementation.patch` carries the git blob hash of the
original `bootstrap/providers.php` (`fc94ae6`). Of the two candidate
skeletons, only `statamic/statamic ^6` produces that file (Laravel 13); `^5`
gives `38b258d` (Laravel 12). Minor versions can share the file, so run 07's
exact 6.x release is unknown.

Run 08's app, from its committed `composer.lock`: **statamic/cms 6.39.0,
laravel/framework 13.39.0, statamic/eloquent-driver 5.12.5**, PHP 8.5.12.

## Steps

All as `ajoy`, `umask 027` (app group-readable for `labshare`), with every
artisan command given its **absolute path** (`php /Users/Shared/lab/app/artisan
…`), which is what `bash_guard`'s lab exemption requires.

1. `composer create-project statamic/statamic app "^6"`, then
   `composer require statamic/eloquent-driver`.
2. `vendor:publish --tag=statamic-eloquent-config` and
   `--tag=statamic-eloquent-blueprint-migrations`. In
   `config/statamic/eloquent-driver.php`, set **blueprints** to `eloquent`;
   everything else stays `file`. Run 07's bug 1 (two mutually exclusive
   `entries` migrations) can't occur, because no entries migrations are
   published.
3. **Users in the database:** `config/statamic/users.php` repository →
   `eloquent`; `config/auth.php` provider `users` → `driver: eloquent`,
   `model: App\Models\User` (the `statamic` driver names no model, so
   `User::make()` fails with "Class name must be a valid object or a string");
   `App\Models\User` casts `preferences` to json and `super` to boolean;
   `php please auth:migration`.
4. `migrate:fresh --force`.
5. `tinker --execute="require '<relay>/…/lab/make_fixture.php';"`: the
   `collections.pages.page` blueprint, body field at
   `tabs.main.sections[0].fields[1]` with display `Body`.
6. `LAB_SPEC_JS=<lab spec copy>/gate.spec.js tinker --execute="require
   '<relay>/…/lab/make_cp_user.php';" 2>&1 | grep '^CP USER:'`: the gate's
   throwaway super user, read from the spec and never printed. Keep the
   `grep`; see the warning in the script.
7. Copy `database/database.sqlite` to the private spec folder as
   `pristine.sqlite` (tables: blueprints, users, auth, cache, jobs; **no
   `blueprint_revisions`**).
8. Playwright for the gate: `npm i --prefix <gate harness> @playwright/test`
   (1.64.1) and `playwright install chromium`.
9. `git init -b main`, commit with a neutral identity
   (`relay-lab <lab@relay.invalid>`). The `.gitignore` excludes `vendor/`,
   `.env`, `*.sqlite` and `public/vendor/statamic`, which `new_trial.sh`
   supplies per trial. `chmod -R g+rX .git` so trial clones can borrow
   objects.

## Not yet done

The gate's runtime user and wrappers, trial group-write, and phase 0. See the
pre-registration's amendments.

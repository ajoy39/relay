# Blueprint revision tracker (Eloquent driver)

**Your app directory**: `{{APP_DIR}}` — work only in there.
`vendor/**` is mounted read-only. Do not touch `/home/user/lab/spec/**`.

## Goal

Statamic is running with `statamic/eloquent-driver`, and blueprints are stored
in the database (`blueprints` table, driver already set to `eloquent`). Editors
change blueprints in the control panel and have no way to see what changed or
go back. Build a revision tracker: every blueprint save records a revision, and
the blueprint edit page lets an editor see the history, preview exactly what
restoring a revision would change, and restore it.

## The HTTP contract (fixed — the gate depends only on this)

Given a blueprint identified by `{namespace}` and `{handle}` (e.g. namespace
`collections.pages`, handle `page`):

1. `GET /cp/blueprint-revisions/{namespace}/{handle}` → JSON
   `{"revisions": [{"id": <string|int>, "created_at": <ISO8601 string>}, ...]}`
   Newest first. Empty list when there is no history.

2. `GET /cp/blueprint-revisions/{namespace}/{handle}/{id}/diff` → JSON
   `{"changes": [{"path": "<dot.path>", "from": <json>, "to": <json>}, ...]}`
   Describing what would change **if this revision were restored** — i.e. from
   the current blueprint contents to the revision's contents. Unchanged values
   must not appear. An identical revision yields `{"changes": []}`.

3. `POST /cp/blueprint-revisions/{namespace}/{handle}/{id}/restore` → JSON
   `{"restored": true}` and the blueprint's stored contents become the
   revision's contents. Restoring must itself record a revision, so a restore
   can be undone.

All three require an authenticated CP user; unauthenticated requests must not
return 200.

## The control panel UI

On the blueprint edit page (`/cp/fields/blueprints/{type}/{handle}/edit`, e.g.
`/cp/fields/blueprints/collections/pages/page/edit`) an editor must be able to:

- see the revision history for that blueprint, each entry showing a timestamp;
- preview what restoring a revision would change, showing the affected field
  paths and their before/after values, without applying anything;
- restore a revision from that page.

The page must contain the literal text `Revisions` so the section is findable,
each revision row must carry the attribute `data-revision-id="<id>"`, the
preview control must carry `data-revision-preview="<id>"`, and the restore
control `data-revision-restore="<id>"`. Those four hooks are fixed so the gate
can drive the page; everything else about the presentation is your choice.

## Invariants

- A blueprint save through Statamic's normal path records a revision. Two edits
  produce two revisions, newest first.
- Restoring changes the blueprint's stored contents and is itself revertible.
- No changes to `vendor/**`. No edits under `/home/user/lab/spec/**`.
- Existing app tests must still pass.

## Non-goals

Revisions for entries, terms, globals or fieldsets. Diffing across namespaces.
Pruning or retention policy. Permissions beyond "authenticated CP user".

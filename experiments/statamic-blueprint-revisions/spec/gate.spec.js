const { test, expect, request } = require('@playwright/test');
const BASE = process.env.BASE_URL || 'http://127.0.0.1:8000';
const NS = 'collections.pages', H = 'page';
const API = `${BASE}/cp/blueprint-revisions/${NS}/${H}`;
const EDIT = `${BASE}/cp/fields/blueprints/collections/pages/page/edit`;
const STATE = process.env.GATE_STATE || '/tmp/gate-storage-state.json';

// Statamic throttles CP logins, so sign in exactly once and share the session.
// Signing in per test made the sixth test fail on the rate limiter, not on the
// implementation under test.
const fs = require('fs');

test.beforeAll(async ({ browser }) => {
  if (fs.existsSync(STATE)) return; // worker restarted after a failure; reuse it
  // storageState: undefined — this context is the one that creates the state.
  const context = await browser.newContext({ storageState: undefined });
  const page = await context.newPage();
  await page.goto(`${BASE}/cp/auth/login`, { waitUntil: 'domcontentloaded' });
  await page.fill('input[name="email"]', 'lab@example.test');
  await page.fill('input[name="password"]', 'labpassword123');
  await Promise.all([
    page.waitForURL(u => !u.toString().includes('/auth/login'), { timeout: 45000, waitUntil: 'commit' }),
    page.click('button[type="submit"], input[type="submit"]'),
  ]);
  await context.storageState({ path: STATE });
  await context.close();
});

test.use({ storageState: STATE });

async function login(_page) { /* session comes from storageState */ }

async function csrfHeaders(page) {
  // A real CP client sends Laravel's CSRF token; page.request does not do this
  // for us. Send both forms so either middleware configuration is satisfied.
  // evaluate, not getAttribute: getAttribute waits for a selector the CP does
  // not always render, and would burn the whole test timeout waiting for it.
  const meta = await page.evaluate(
    () => document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') ?? null
  ).catch(() => null);
  const cookies = await page.context().cookies();
  const xsrf = cookies.find(c => c.name === 'XSRF-TOKEN');
  const headers = { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest' };
  if (meta) headers['X-CSRF-TOKEN'] = meta;
  if (xsrf) headers['X-XSRF-TOKEN'] = decodeURIComponent(xsrf.value);
  return headers;
}

async function fetchRevisions(page) {
  const res = await page.request.get(API);
  if (res.status() !== 200) return [];
  const b = await res.json().catch(() => ({}));
  return Array.isArray(b.revisions) ? b.revisions : [];
}

test('1. revisions endpoint lists history newest-first', async ({ page }) => {
  await login(page);
  const res = await page.request.get(API);
  expect(res.status(), 'GET revisions status').toBe(200);
  const body = await res.json();
  expect(Array.isArray(body.revisions), 'body.revisions is an array').toBeTruthy();
  expect(body.revisions.length, 'at least 2 revisions after 2 edits').toBeGreaterThanOrEqual(2);
  for (const r of body.revisions) {
    expect(r.id, 'revision has id').toBeDefined();
    expect(Date.parse(r.created_at), 'created_at parses').not.toBeNaN();
  }
  const times = body.revisions.map(r => Date.parse(r.created_at));
  expect(times, 'newest first').toEqual([...times].sort((a, b) => b - a));
});

test('2. diff endpoint reports what restoring would change', async ({ page }) => {
  await login(page);
  const revisions = await fetchRevisions(page);
  expect(revisions.length, 'history available').toBeGreaterThan(0);
  const oldest = revisions[revisions.length - 1];
  const res = await page.request.get(`${API}/${oldest.id}/diff`);
  expect(res.status(), 'GET diff status').toBe(200);
  const body = await res.json();
  expect(Array.isArray(body.changes), 'body.changes is an array').toBeTruthy();
  expect(body.changes.length, 'oldest revision differs from current').toBeGreaterThan(0);
  const c = body.changes[0];
  expect(c).toHaveProperty('path');
  expect(c).toHaveProperty('from');
  expect(c).toHaveProperty('to');
});

test('3. unauthenticated access is refused', async ({ page }) => {
  // every /cp URL redirects anon to login, so a missing route would refuse
  // anon too. Require that the endpoint actually exists first.
  const authed = await page.request.get(API);
  expect(authed.status(), 'endpoint must answer a signed-in CP user').toBe(200);
  // storageState: undefined — the test runner otherwise injects the shared
  // signed-in state into this context and the request stops being anonymous.
  const anon = await request.newContext({ storageState: undefined });
  // do not follow the redirect: a 302 to the login screen would otherwise
  // arrive here as a 200 and look like an unguarded route.
  const res = await anon.get(API, { maxRedirects: 0 });
  expect([401, 403, 302, 419], `route must exist and refuse anon (got ${res.status()})`).toContain(res.status());
  await anon.dispose();
});

test('4. blueprint edit page exposes history, preview and restore', async ({ page }) => {
  await login(page);
  await page.goto(EDIT, { waitUntil: 'networkidle' });
  const text = await page.textContent('body');
  expect(text, 'page mentions Revisions').toContain('Revisions');
  const rows = await page.$$('[data-revision-id]');
  expect(rows.length, 'revision rows rendered').toBeGreaterThanOrEqual(2);
  const revisions = await fetchRevisions(page);
  expect(revisions.length, 'history available').toBeGreaterThan(0);
  const id = revisions[revisions.length - 1].id;
  expect(await page.$(`[data-revision-preview="${id}"]`), 'preview control present').not.toBeNull();
  expect(await page.$(`[data-revision-restore="${id}"]`), 'restore control present').not.toBeNull();
});

test('5. preview shows the changed path without applying it', async ({ page }) => {
  await login(page);
  await page.goto(EDIT, { waitUntil: 'networkidle' });
  const revisions = await fetchRevisions(page);
  expect(revisions.length, 'history available').toBeGreaterThan(0);
  const id = revisions[revisions.length - 1].id;
  const before = await page.textContent('body');
  const preview = page.locator(`[data-revision-preview="${id}"]`).first();
  await preview.scrollIntoViewIfNeeded().catch(() => {});
  await preview.click({ timeout: 10000 }).catch(() => preview.dispatchEvent('click'));
  await page.waitForTimeout(2500);
  const after = await page.textContent('body');
  expect(after.length, 'preview rendered something new').toBeGreaterThan(before.length);
  expect(/display|body/i.test(after), 'preview names an affected path').toBeTruthy();
});

test('6. restore reverts the blueprint and is itself recorded', async ({ page }) => {
  await login(page);
  const revisions = await fetchRevisions(page);
  expect(revisions.length, 'history available').toBeGreaterThan(0);
  const oldest = revisions[revisions.length - 1];
  await page.goto(EDIT, { waitUntil: 'domcontentloaded' });
  const res = await page.request.post(`${API}/${oldest.id}/restore`, { headers: await csrfHeaders(page) });
  expect(res.status(), 'POST restore status').toBe(200);
  expect((await res.json()).restored, 'restored:true').toBe(true);
  const after = await (await page.request.get(API)).json();
  expect(after.revisions.length, 'restore recorded a new revision').toBeGreaterThan(revisions.length);
});

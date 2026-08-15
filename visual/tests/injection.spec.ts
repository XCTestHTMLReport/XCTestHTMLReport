import { test, expect } from '@playwright/test';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const reportURL = pathToFileURL(resolve(__dirname, '../fixtures/report.html')).href;

// The synthetic fixture carries one attachment whose file name contains every
// character that has to be escaped on the way into markup. Asserting on the
// rendered source only proves the bytes changed; these assert on what the
// browser actually built out of them.
const HOSTILE_FILENAME =
  'FileName with DoubleQuote"SingleQuote\'LessThan<GreaterThan>Ampersand&.txt';

// `.preview-button` since A3a (#439): the control that carries the file name
// and the handler is a real `<button>` now, with the masked eye as a span
// inside it. The two elements exist because a CSS mask clips everything its
// element paints, focus ring included, so the ring and the glyph cannot be the
// same box — and this control had no keyboard path at all before.
const previewIcons = (page: import('@playwright/test').Page) =>
  page.locator('.attachment .preview-button');

test('a hostile attachment filename does not put an element in the DOM', async ({ page }) => {
  await page.goto(reportURL);

  // Unescaped, `<GreaterThan>` was parsed as a start tag: the parser built an
  // element out of an attachment's name.
  await expect(page.locator('greaterthan')).toHaveCount(0);
});

test('a hostile attachment filename reaches its attribute whole', async ({ page }) => {
  await page.goto(reportURL);

  const names = await previewIcons(page).evaluateAll((nodes) =>
    nodes.map((node) => node.getAttribute('data')));

  expect(names.length, 'the fixture must render attachment previews').toBeGreaterThan(0);
  expect(
    names,
    'the embedded double quote must not terminate the attribute and truncate the name',
  ).toContain(HOSTILE_FILENAME);
});

test('clicking a preview icon previews the attachment it names', async ({ page }) => {
  await page.goto(reportURL);

  const icons = previewIcons(page);
  const index = (await icons.evaluateAll((nodes) =>
    nodes.map((node) => node.getAttribute('data')))).indexOf(HOSTILE_FILENAME);
  expect(index, 'the fixture must contain the hostile attachment').toBeGreaterThanOrEqual(0);

  // Dispatched rather than clicked: the attachment sits inside a collapsed
  // activity, and what is under test is the handler wiring, not the
  // disclosure it lives behind.
  await icons.nth(index).dispatchEvent('click');

  await expect(
    page.locator('#text-attachment'),
    'the handler must open the file it names, not a prefix of it',
  ).toHaveAttribute('src', HOSTILE_FILENAME);
});

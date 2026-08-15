import { test, expect, type Page } from '@playwright/test';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

// The per-view shell (#439, A3a). Everything here is behaviour the rendered
// HTML cannot show: which surface owns the window, what a keyboard can reach,
// and whether the header picker really does the whole of the job the device
// sidebar used to do.
const reportURL = pathToFileURL(resolve(__dirname, '../fixtures/report.html')).href;

// A report built from two bundles — the case the sidebar existed for, and the
// only one on which "switch destination" can be caught doing the wrong thing.
const multiURL = pathToFileURL(resolve(__dirname, '../fixtures/report-multi.html')).href;

const activeTree = (page: Page) => page.locator('#view-tests .run-view.active .tests');

// ---- Navigation parity --------------------------------------------------
//
// The sidebar could do four things: say which destinations a report holds,
// say how each one did, say which one is on screen, and switch to another.
// These are those four, on the control that replaced it.

test('the picker lists every destination with its own outcome', async ({ page }) => {
  await page.goto(multiURL);

  const options = page.locator('.device-option');
  await expect(options, 'a two-bundle report must offer both runs').toHaveCount(2);

  // The run number is rendered only when a report holds several runs, and it
  // is what keeps two options apart when their destinations are identical —
  // merging a bundle with itself, or two bundles from one simulator. This
  // fixture's destinations differ, so it is proving the number is there at all.
  await expect(options.nth(0).locator('.device-row-name'))
    .toHaveText('Synthetic Device 1.0 Run 1');
  await expect(options.nth(1).locator('.device-row-name'))
    .toHaveText('Synthetic Device Two 2.0 Run 2');

  // Each option carries its own run's split, not the report's total — that is
  // what the summary band's ring is for.
  for (const index of [0, 1]) {
    await expect(
      options.nth(index).locator('.device-row-tally'),
      'every option states its own run in words, since the bar is aria-hidden',
    ).toHaveText('1 passed, 1 failed, 1 skipped, 1 mixed, 1 expected failure');
  }

  await expect(
    page.locator('#device-picker-current'),
    'the collapsed picker names the destination on screen',
  ).toHaveText('Synthetic Device 1.0 Run 1');
});

test('picking a destination switches the tests tree and the log together', async ({ page }) => {
  await page.goto(multiURL);

  const [first, second] = await page.locator('.device-option')
    .evaluateAll((nodes) => nodes.map((node) => node.getAttribute('data-device')));

  await expect(page.locator(`#tests_${first}`)).toBeVisible();
  await expect(page.locator(`#logs_${first}`)).toHaveClass(/active/);

  await page.locator('#device-picker summary').click();
  await page.locator(`.device-option[data-device="${second}"]`).click();

  await expect(page.locator(`#tests_${first}`), 'the old tree must leave').toBeHidden();
  await expect(page.locator(`#tests_${second}`), 'the new tree must arrive').toBeVisible();
  // The half the old shell could not get wrong and the new one could: the two
  // views are separate subtrees now, so the log has to be switched explicitly.
  await expect(
    page.locator(`#logs_${second}`),
    'the log must follow the tree, or the Logs view would show the run the reader just left',
  ).toHaveClass(/active/);
  await expect(page.locator(`#logs_${first}`)).not.toHaveClass(/active/);

  await expect(page.locator('#device-picker-current'))
    .toHaveText('Synthetic Device Two 2.0 Run 2');
  await expect(
    page.locator('#device-picker'),
    'choosing dismisses the panel',
  ).not.toHaveAttribute('open', '');
});

// The reason the picker is in the title band and not in the summary band: the
// band stands down for the Logs view (A2), and every run has its own log, so a
// picker inside it would be unreachable on exactly the view that needs it.
test('the picker still switches destination from the Logs view', async ({ page }) => {
  await page.goto(multiURL);

  await page.locator('#tab-logs').click();
  await expect(page.locator('#run-summary')).toBeHidden();
  await expect(page.locator('#device-picker'), 'the picker outlives the band').toBeVisible();

  const second = (await page.locator('.device-option').nth(1).getAttribute('data-device'))!;
  await page.locator('#device-picker summary').click();
  await page.locator(`.device-option[data-device="${second}"]`).click();

  await expect(
    page.locator(`#view-logs #logs_${second}`),
    'the log on screen must be the one just chosen',
  ).toBeVisible();
  await expect(page.locator('#view-tests'), 'and the view must not change under them')
    .toBeHidden();
});

test('a digest jump into another destination brings the picker with it', async ({ page }) => {
  await page.goto(multiURL);

  const second = (await page.locator('.device-option').nth(1).getAttribute('data-device'))!;
  // The digest lists every run's failures; the second one belongs to a run
  // that is not on screen.
  const jump = page.locator('.digest-jump').nth(1);
  await jump.click();

  await expect(page.locator(`#tests_${second}`)).toBeVisible();
  await expect(
    page.locator('#device-picker-current'),
    'the header must not still name the destination the reader left',
  ).toHaveText('Synthetic Device Two 2.0 Run 2');
  await expect(
    page.locator(`.device-option[data-device="${second}"]`),
    'and the option must read as the current one',
  ).toHaveAttribute('aria-current', 'true');
});

// ---- Per-view surfaces --------------------------------------------------

test('each view owns its own toolbar and nothing else renders under it', async ({ page }) => {
  await page.goto(reportURL);

  await expect(
    page.locator('#view-tests .view-toolbar .filter-pills'),
    'the status filters belong to the Tests view',
  ).toBeVisible();

  await page.locator('#tab-logs').click();
  await expect(page.locator('#view-logs .view-toolbar')).toBeVisible();
  await expect(
    page.locator('#view-tests .view-toolbar'),
    'the Tests toolbar leaves with the Tests view',
  ).toBeHidden();
});

test('the trailing toolbar slot A3b fills is laid out and empty', async ({ page }) => {
  await page.goto(reportURL);

  const trailing = page.locator('#view-tests .run-view.active .view-toolbar-trailing');
  await expect(trailing, 'the slot must exist for #460 to land in').toHaveCount(1);
  await expect(trailing, 'and be empty until it does').toHaveText('');

  // Right-aligned, which is the half that makes it a slot rather than a div:
  // A3b's filter field lands at the far end of the toolbar, as Xcode's does.
  const [toolbarRight, slotRight] = await page.evaluate(() => {
    const toolbar = document.querySelector('#view-tests .run-view.active .view-toolbar')!;
    const slot = toolbar.querySelector('.view-toolbar-trailing')!;
    return [toolbar.getBoundingClientRect().right, slot.getBoundingClientRect().right];
  });
  expect(Math.abs(toolbarRight - slotRight)).toBeLessThanOrEqual(12);
});

// ---- The attachment sheet ----------------------------------------------

test('the attachment sheet is summoned, dismissable, and absent from Logs', async ({ page }) => {
  await page.goto(reportURL);

  const sheet = page.locator('#attachment-sheet');
  await expect(sheet, 'nothing reserves space for an attachment nobody asked for')
    .toBeHidden();

  // Open the disclosures the attachment lives behind, the way a reader would.
  await page.evaluate(() => {
    const row = [...document.querySelectorAll('#view-tests .run-view.active '
      + '.test-summary > p.list-item')]
      .find((el) => el.textContent!.includes('testPasses()'))!;
    (row.querySelector('.drop-down-icon') as HTMLElement).click();
    const activity = [...row.parentElement!.querySelectorAll('.activity > p.list-item')]
      .find((el) => el.textContent!.includes('Attachments'))!;
    (activity.querySelector('.drop-down-icon') as HTMLElement).click();
  });

  // Keyboard, not a click: the eye was a `<span onclick>` before A3a, so the
  // only way to open an attachment was to point at it.
  const preview = page.locator('.attachment .preview-button:visible').first();
  await preview.focus();
  await expect(preview, 'the control must be reachable by a keyboard').toBeFocused();
  await page.keyboard.press('Enter');

  await expect(sheet, 'a preview must summon the sheet').toBeVisible();
  await expect(
    sheet.locator('#attachment-sheet-title'),
    'and it must say what is in it',
  ).not.toHaveText('Attachment');

  await page.locator('#attachment-close').click();
  await expect(sheet, 'and Close must dismiss it').toBeHidden();
});

// Inline mode is the other half of "both render modes", and it is the half the
// old handler could not serve: it embeds every payload as a `data:` URI, and
// the script decided what kind of attachment it had by splitting the path on
// `.` and reading the last piece — which for `data:image/png;base64,iVBOR…`
// is a base64 tail, matching nothing. `data-kind`, written by the template
// that knows, is what makes the two modes the same code path.
test('an inline-mode attachment opens in the sheet', async ({ page }) => {
  await page.goto(pathToFileURL(resolve(__dirname, '../fixtures/report-inline.html')).href);

  const preview = page.locator('.attachment .preview-button[data-kind="screenshot"]').first();
  await expect(
    preview,
    'inline mode must still carry the kind, not just the payload',
  ).toHaveCount(1);
  await preview.dispatchEvent('click');

  await expect(page.locator('#attachment-sheet')).toBeVisible();
  await expect(
    page.locator('#screenshot'),
    'the image must be the one shown, not a download link for a data: URI',
  ).toBeVisible();
  await expect(page.locator('#screenshot')).toHaveAttribute('src', /^data:image\/png;base64,/);
});

test('nothing attachment-shaped exists while the Logs view is showing', async ({ page }) => {
  await page.goto(reportURL);

  await page.locator('#tab-logs').click();

  // Not merely invisible: `display: none` on the view takes the whole subtree
  // out of the accessibility tree, so a screen reader on Logs cannot walk into
  // it either.
  await expect(page.locator('#attachment-sheet')).toBeHidden();
  await expect(page.locator('#view-logs .attachment-sheet')).toHaveCount(0);
  await expect(page.locator('#view-logs .preview-button')).toHaveCount(0);
});

// ---- Keyboard -----------------------------------------------------------

test('the view tabs are a keyboard-navigable tablist', async ({ page }) => {
  await page.goto(reportURL);

  await page.locator('#tab-tests').focus();
  await expect(page.locator('#tab-tests')).toHaveAttribute('aria-selected', 'true');

  await page.keyboard.press('ArrowRight');
  await expect(page.locator('#tab-logs'), 'the arrow must select as it moves')
    .toHaveAttribute('aria-selected', 'true');
  await expect(page.locator('#view-logs')).toBeVisible();
  await expect(page.locator('#tab-logs')).toBeFocused();

  // A roving tab stop: one press of Tab leaves the whole tablist, rather than
  // stepping through every tab in it.
  await expect(page.locator('#tab-tests')).toHaveAttribute('tabindex', '-1');

  await page.keyboard.press('ArrowLeft');
  await expect(page.locator('#view-tests')).toBeVisible();
});

test('the status filters are a keyboard-navigable radiogroup', async ({ page }) => {
  await page.goto(reportURL);

  const rows = () => page.locator('#view-tests .run-view.active .test-summary:visible').count();
  const all = await rows();

  const pills = page.locator('#view-tests .run-view.active .pill');
  await pills.first().focus();
  await page.keyboard.press('ArrowRight');

  await expect(pills.nth(1), 'the arrow must choose as it moves')
    .toHaveAttribute('aria-checked', 'true');
  await expect(pills.first()).toHaveAttribute('aria-checked', 'false');
  expect(await rows(), 'and choosing must actually filter').toBeLessThan(all);
});

test('the picker opens and closes from the keyboard', async ({ page }) => {
  await page.goto(reportURL);

  const summary = page.locator('#device-picker summary');
  await summary.focus();
  await page.keyboard.press('Enter');
  await expect(page.locator('#device-picker')).toHaveAttribute('open', '');
  await expect(
    page.locator('.device-option').first(),
    'the options are real buttons, so Tab reaches them',
  ).toBeEnabled();

  await page.keyboard.press('Escape');
  await expect(page.locator('#device-picker')).not.toHaveAttribute('open', '');
  await expect(summary, 'Escape must give focus back to the control it closed')
    .toBeFocused();
});

// Focus inside a panel that is about to be `display: none` is dropped to
// <body> by the browser, which loses a keyboard reader's place entirely.
test('switching view never strands focus on a hidden element', async ({ page }) => {
  await page.goto(reportURL);

  await activeTree(page).focus();
  await expect(activeTree(page)).toBeFocused();

  // Dispatched, not clicked: a click would move focus to the tab by itself and
  // the assertion would hold for the wrong reason.
  await page.locator('#tab-logs').dispatchEvent('click');

  await expect(page.locator('#tab-logs'), 'focus must land somewhere reachable')
    .toBeFocused();
  const stranded = await page.evaluate(() =>
    document.querySelector('#view-tests')!.contains(document.activeElement));
  expect(stranded, 'focus must not remain inside the hidden view').toBe(false);
});

test('clicking a row leaves the tree focused so the arrows carry on', async ({ page }) => {
  await page.goto(reportURL);

  await page.locator('#view-tests .run-view.active .test-summary > p.list-item')
    .first().click();
  await expect(
    activeTree(page),
    'the tree is the focusable scroll region, and a click has to land in it',
  ).toBeFocused();
});

// The tree claims the arrow keys, but only while it is the thing being read.
// Before A3a nothing in the page could take focus, so a document-level handler
// could not collide with anything; now it can.
test('the tree does not steal the arrow keys from a toolbar', async ({ page }) => {
  await page.goto(reportURL);

  await page.locator('#view-tests .run-view.active .test-summary > p.list-item')
    .first().click();
  const selected = await page.locator('#view-tests .run-view.active .list-item.selected')
    .first().textContent();

  await page.locator('#view-tests .run-view.active .pill').first().focus();
  await page.keyboard.press('ArrowDown');

  await expect(
    page.locator('#view-tests .run-view.active .list-item.selected').first(),
    'the arrow belonged to the radiogroup, so the tree selection must not move',
  ).toHaveText(selected!.trim());
});

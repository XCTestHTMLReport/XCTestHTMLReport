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
    ).toHaveText('2 passed, 1 failed, 1 skipped, 1 mixed, 1 expected failure');
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

// Switching destination abandons the selection, because the row it named goes
// `display: none` with the run it belongs to. Abandoning it in the script and
// leaving it painted in the page are different things, and the difference only
// shows on the way back: the hidden row keeps its fill, returns still wearing
// it, and — since the script no longer holds it — the next row selected gets a
// second fill rather than moving the first. Two rows then claim a selection the
// sheet is answering for one of.
test('a destination round-trip leaves exactly one row highlighted', async ({ page }) => {
  await page.goto(multiURL);

  const [first, second] = await page.locator('.device-option')
    .evaluateAll((nodes) => nodes.map((node) => node.getAttribute('data-device')));
  const pick = async (device: string | null) => {
    await page.locator('#device-picker summary').click();
    await page.locator(`.device-option[data-device="${device}"]`).click();
  };
  // Document-wide, not scoped to the active run: a stale fill left behind in a
  // hidden run is exactly what a scoped count cannot see.
  const highlighted = page.locator('.list-item.selected');
  const rows = page.locator('#view-tests .run-view.active .test-summary > p.list-item');

  await rows.first().click();
  await expect(highlighted, 'clicking a row selects it').toHaveCount(1);

  await pick(second);
  await expect(
    highlighted,
    'the selection belongs to the run that left, so nothing may still be painted',
  ).toHaveCount(0);

  await pick(first);
  await expect(
    highlighted,
    'and it must not come back with the run it was abandoned in',
  ).toHaveCount(0);

  await rows.nth(1).click();
  await expect(
    highlighted,
    'selecting after a round-trip must move the highlight, not add a second one',
  ).toHaveCount(1);
  await expect(highlighted.first()).toHaveText(await rows.nth(1).innerText());
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

// The slot A3a reserved, now filled (#439, A3b). Right-aligned is the half
// that made it a slot rather than a div, and it is where Xcode's own test
// report puts its Filter field — so this asserts the position as well as the
// presence.
test('both views carry a filter field at the far end of their toolbar', async ({ page }) => {
  await page.goto(reportURL);

  for (const [view, tab] of [['#view-tests', '#tab-tests'], ['#view-logs', '#tab-logs']]) {
    await page.locator(tab).click();
    const field = page.locator(`${view} .run-view.active .view-toolbar-trailing input.view-filter`);
    await expect(field, `${view} must carry a filter field`).toHaveCount(1);
    await expect(field).toBeVisible();

    const gap = await page.evaluate((selector) => {
      const toolbar = document.querySelector(`${selector} .run-view.active .view-toolbar`)!;
      const slot = toolbar.querySelector('.view-toolbar-trailing')!;
      return toolbar.getBoundingClientRect().right - slot.getBoundingClientRect().right;
    }, view);
    expect(Math.abs(gap), `${view}'s filter must sit at the trailing edge`)
      .toBeLessThanOrEqual(12);
  }
});

// 375px, where the toolbar has the most to fit and the least room: six pills,
// a count and a field. The pills wrap and the field gives way — `max-width`
// on the field, `flex-wrap` on the row — and what must not happen is the
// toolbar pushing the page sideways, because `body` is `overflow: hidden` and
// anything past the right edge is not merely unscrolled but unreachable (the
// A3a title-band defect, in the row below it).
test('the filled toolbar stays inside a 375px window', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 });
  await page.goto(reportURL);

  const geometry = await page.evaluate(() => {
    const toolbar = document.querySelector('#view-tests .run-view.active .view-toolbar')!;
    const field = toolbar.querySelector('.view-filter')!;
    const pills = [...toolbar.querySelectorAll('.pill')];
    return {
      toolbarRight: toolbar.getBoundingClientRect().right,
      fieldRight: field.getBoundingClientRect().right,
      fieldWidth: field.getBoundingClientRect().width,
      pillRows: new Set(pills.map((p) => Math.round(p.getBoundingClientRect().top))).size,
      pills: pills.length,
      viewport: document.documentElement.clientWidth,
      bodyScroll: document.documentElement.scrollWidth,
    };
  });

  // Precondition, in the A2 pattern: a toolbar that fitted on one line would
  // pass every assertion below while proving nothing about the case this
  // exists for.
  expect(geometry.pills, 'the fixture must offer enough pills to crowd the row')
    .toBeGreaterThanOrEqual(5);
  expect(geometry.pillRows, 'and they must actually have wrapped at this width')
    .toBeGreaterThan(1);

  expect(geometry.fieldRight, 'the filter field must not overhang the toolbar')
    .toBeLessThanOrEqual(geometry.toolbarRight + 1);
  expect(geometry.fieldWidth, 'and must still be wide enough to type in')
    .toBeGreaterThan(60);
  expect(geometry.bodyScroll, 'nothing may push the page sideways')
    .toBeLessThanOrEqual(geometry.viewport + 1);
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

// ---- 375px --------------------------------------------------------------

// The length of the destination that found this: "iPhone 17 Pro Max 26.2 Run 1"
// — a stock simulator on a report merged from two bundles, which is the
// ordinary case, not a contrived one. Characters rather than pixels because
// this suite runs on macOS locally and on Linux in CI and the two do not share
// a font; what has to be pinned is that the name under test is as long as a
// real one, and a count says that in a unit both platforms agree on.
const REAL_DESTINATION = 'iPhone 17 Pro Max 26.2 Run 1';

// `body` sets `overflow: hidden`, so a title band that does not fit is not
// scrolled to — it is cut off, chevron and border and the tail of the name
// with it. The rule that was supposed to prevent that is `text-overflow:
// ellipsis` on the summary's name, and it did nothing: a flex item's automatic
// minimum is its content's, a `nowrap` string's min-content is the whole
// string, so nothing in the chain ever shrank and there was no overflow for
// the ellipsis to elide.
//
// The gate this replaces could not have caught it. It measured the single-run
// fixture, whose destination is short enough that the row fit — by squeezing
// the run's status glyph from 24px to 11px, which is its own defect and is why
// the glyph is measured below too. A short name hid a clip that every real
// report shows, so this test states the length it needs and fails if the
// fixture stops providing it.
test(`the title band fits a 375px viewport with a ${REAL_DESTINATION.length}-character `
  + 'destination', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 });
  await page.goto(multiURL);

  // The longer of the fixture's two destinations, which is also the one a
  // reader arrives at by switching — the picker is at its widest after use.
  const second = (await page.locator('.device-option').nth(1).getAttribute('data-device'))!;
  await page.locator('#device-picker summary').click();
  await page.locator(`.device-option[data-device="${second}"]`).click();

  const band = await page.evaluate(() => {
    const right = (selector: string) =>
      document.querySelector(selector)!.getBoundingClientRect().right;
    const title = document.getElementById('title')!;
    const current = document.getElementById('device-picker-current')!;
    const glyph = document.querySelector('#title > .icon')!.getBoundingClientRect();
    return {
      viewport: document.documentElement.clientWidth,
      body: document.body.scrollWidth,
      titleOverflow: title.scrollWidth - title.clientWidth,
      summaryRight: right('#device-picker > summary'),
      chevronRight: right('.picker-chevron'),
      name: current.textContent!.trim(),
      truncated: current.scrollWidth > current.clientWidth,
      glyph: { width: glyph.width, height: glyph.height },
    };
  });

  // The precondition, in the pattern the axe gate uses: a name short enough to
  // fit is a name this test passes for free, and it would say nothing about
  // the clip. This is the assertion that keeps the fixture honest.
  expect(
    band.name.length,
    `the fixture's destination must be at least as long as a real one `
      + `("${REAL_DESTINATION}"), or this gate is measuring a name that fits — got "${band.name}"`,
  ).toBeGreaterThanOrEqual(REAL_DESTINATION.length);

  expect(band.body, 'nothing may sit sideways of a viewport that cannot scroll')
    .toBeLessThanOrEqual(band.viewport);
  expect(band.titleOverflow, 'the title band must fit the width it is given')
    .toBeLessThanOrEqual(0);
  expect(
    band.summaryRight,
    'the picker summary must end on screen — its border says where the control stops',
  ).toBeLessThanOrEqual(band.viewport);
  expect(
    band.chevronRight,
    'and the chevron must be on screen, since it is what says the control opens',
  ).toBeLessThanOrEqual(band.viewport);
  // Square, and not squarely nothing: the glyph is sized in one axis by a rule
  // and in the other by the flex row, so "width matches height" alone would be
  // satisfied by an element that had vanished in both.
  expect(band.glyph.height, 'the run glyph must be in the layout').toBeGreaterThan(0);
  expect(
    band.glyph.width,
    'and must keep its shape rather than absorb the squeeze for everything else',
  ).toBeCloseTo(band.glyph.height, 0);
  expect(
    band.truncated,
    'and the name must give way by eliding: with a real destination at this '
      + 'width its tail belongs under an ellipsis, not off the side of the screen',
  ).toBe(true);
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

// Both ways out of the panel, on the fixture where choosing means something:
// Escape, and choosing an option. Each closes a `<details>` while focus is
// inside it, which the browser answers by dropping focus to `<body>` — the
// same thing `showView` guards against for the view tabs, and a keyboard
// reader's next Tab restarts from the top of the document.
test('the picker opens, chooses and closes from the keyboard', async ({ page }) => {
  await page.goto(multiURL);

  const summary = page.locator('#device-picker summary');
  const options = page.locator('.device-option');
  await summary.focus();
  await page.keyboard.press('Enter');
  await expect(page.locator('#device-picker')).toHaveAttribute('open', '');

  // Tab, not `focus()`: the claim is that the options are real buttons in the
  // document's own order, so a keyboard reaches them without a widget.
  await page.keyboard.press('Tab');
  await expect(options.first(), 'Tab must step into the panel').toBeFocused();
  await page.keyboard.press('Tab');
  await expect(options.nth(1), 'and on through it').toBeFocused();

  await page.keyboard.press('Enter');
  await expect(page.locator('#device-picker')).not.toHaveAttribute('open', '');
  await expect(
    page.locator('#device-picker-current'),
    'the destination must actually have switched',
  ).toHaveText('Synthetic Device Two 2.0 Run 2');

  // Settled, because focus moves out of a hidden element over a frame: an
  // immediate read still sees the option and passes for the wrong reason.
  await page.evaluate(() => new Promise<void>((resolve) => {
    requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
  }));
  expect(
    await page.evaluate(() => document.activeElement?.tagName),
    'choosing must not drop a keyboard reader onto <body>',
  ).not.toBe('BODY');
  await expect(
    summary,
    'the summary is where the reader was and it now names what they chose',
  ).toBeFocused();

  await summary.focus();
  await page.keyboard.press('Enter');
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

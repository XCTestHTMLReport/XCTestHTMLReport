import { test, expect } from '@playwright/test';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const reportURL = pathToFileURL(resolve(__dirname, '../fixtures/report.html')).href;

test('the failed filter hides passing tests', async ({ page }) => {
  await page.goto(reportURL);

  const visibleRows = () => page.locator('#view-tests .run-view.active .test-summary:visible').count();

  const all = await visibleRows();
  expect(all, 'fixture must render test rows').toBeGreaterThan(0);

  await page.locator('.pill', { hasText: /^Failed \(\d+\)$/ }).click();
  const failed = await visibleRows();

  expect(failed, 'filtering to Failed must hide rows').toBeLessThan(all);
  expect(failed, 'the fixture has failing tests, so some rows must remain').toBeGreaterThan(0);
});

// ---- #460: the expected-failure bucket ----------------------------------
//
// The defect, stated as the page saw it: an expected failure carries
// `.expected-failure` and none of the four classes the old filters knew, so
// "Passed" left it on screen — a reader asking for the tests that passed was
// shown one that did not — and "All" could not put it back, because "All" only
// ever set `display: block` on those same four. The group pass then read the
// row as hidden, so a suite of nothing but expected failures vanished from the
// tree the moment the reader touched any filter, "All" included.
//
// Three assertions, because each half fails differently: the pill exists, it
// selects exactly its own rows, and every other pill hides them.
test('expected failures have a filter of their own', async ({ page }) => {
  await page.goto(reportURL);

  const scope = '#view-tests .run-view.active';
  const expected = page.locator(`${scope} .test-summary.expected-failure`);
  const visible = () => page.locator(`${scope} .test-summary:visible`).count();

  expect(
    await expected.count(),
    'the fixture must hold an expected failure, or nothing here is under test',
  ).toBeGreaterThan(0);

  const pill = page.locator('.pill', { hasText: /^Expected failures \(\d+\)$/ });
  await expect(pill, '#460: the status must have a pill').toHaveCount(1);

  await pill.click();
  await expect(expected.first(), 'choosing it must show the expected failures').toBeVisible();
  expect(
    await visible(),
    'and only those',
  ).toBe(await expected.count());

  // The half the old code could not do at all.
  await page.locator('.pill', { hasText: /^Passed \(\d+\)$/ }).click();
  await expect(
    expected.first(),
    'a reader asking for passing tests must not be shown an expected failure',
  ).toBeHidden();

  await page.locator('.pill', { hasText: /^All \(\d+\)$/ }).click();
  await expect(expected.first(), 'and "All" must bring it back').toBeVisible();
});

// The consequence of the same defect one level up. A suite whose rows are all
// expected failures had every row unfiltered and therefore, to the group pass,
// no visible rows at all — so the suite was hidden while the reader was asking
// to see everything.
test('a suite of expected failures survives every filter that should show it', async ({ page }) => {
  await page.goto(reportURL);

  const groups = page.locator('#view-tests .run-view.active .test-summary-group');
  const withExpected = groups.filter({ has: page.locator('.test-summary.expected-failure') });
  expect(await withExpected.count(), 'the fixture must hold such a suite').toBeGreaterThan(0);

  for (const label of [/^All \(\d+\)$/, /^Expected failures \(\d+\)$/]) {
    await page.locator('.pill', { hasText: label }).click();
    await expect(
      withExpected.first(),
      `the suite holding an expected failure must stay in the tree under ${label}`,
    ).toBeVisible();
  }
});

// ---- The name filter ----------------------------------------------------

test('the name filter narrows the tree and composes with the pills', async ({ page }) => {
  await page.goto(reportURL);

  const scope = '#view-tests .run-view.active';
  const visible = () => page.locator(`${scope} .test-summary:visible`).count();
  const field = page.locator(`${scope} .tests-filter`);

  const all = await visible();
  expect(all, 'fixture must render test rows').toBeGreaterThan(1);

  await field.fill('testFails');
  const named = await visible();
  expect(named, 'typing a name must hide the rows that do not match').toBeLessThan(all);
  expect(named, 'and keep the one that does').toBeGreaterThan(0);
  // `> p.list-item >`, because a retried row nests an iteration row inside it
  // and every one of those carries a `.row-name` of its own.
  await expect(page.locator(`${scope} .test-summary:visible > p.list-item > .row-name`))
    .toHaveText([/testFails/]);

  // Composed, not replaced: a status that excludes the named row must leave
  // nothing, which is what "both filters apply" means and what a filter that
  // reset its neighbour would get wrong.
  await page.locator('.pill', { hasText: /^Passed \(\d+\)$/ }).click();
  expect(await visible(), 'Passed + "testFails" selects nothing').toBe(0);

  await field.fill('');
  const passing = await visible();
  expect(passing, 'clearing the field leaves the status filter in effect')
    .toBeGreaterThan(0);
  expect(passing, 'which still hides the failing rows').toBeLessThan(all);
});

// A filter over a tree has to read the tree, not only its leaves: typing the
// name of a suite that is on screen must keep that suite and the tests inside
// it, which is what the same query does in Xcode's outline. Matching leaves
// alone would empty the pane on a name the reader can see.
test('the name filter matches suite names too', async ({ page }) => {
  await page.goto(reportURL);

  const scope = '#view-tests .run-view.active';
  const suite = page.locator(`${scope} .test-summary-group`).first();
  const suiteName = (await suite.locator('.row-name').first().textContent())!.trim();
  expect(suiteName.length, 'the fixture must name its suites').toBeGreaterThan(0);

  const rowsUnderSuite = await suite.locator('.test-summary').count();
  expect(rowsUnderSuite, 'and put tests inside them').toBeGreaterThan(0);
  // The precondition that makes this a test of ancestry rather than of
  // substring matching: no test row may carry the suite's name itself.
  const selfNamed = await page.locator(`${scope} .test-summary > p.list-item > .row-name`)
    .evaluateAll((els, name) => els.filter((el) => el.textContent!.includes(name)).length, suiteName);
  expect(selfNamed, 'no row may match the suite name on its own').toBe(0);

  await page.locator(`${scope} .tests-filter`).fill(suiteName);
  await expect(suite, 'the suite the reader named must stay').toBeVisible();
  expect(
    await page.locator(`${scope} .test-summary:visible`).count(),
    'and bring the tests inside it',
  ).toBe(rowsUnderSuite);
});

// A suite whose every row a filter hid must go with them, however deep it is.
// The pass A3b replaces bailed out on any group holding a sub-group, so the
// legacy backend's two wrapper levels — "Selected tests" and
// "<target>.xctest", which hold only other groups — survived every filter: two
// selected rows sat under three empty headings.
test('a suite goes when its last visible row does', async ({ page }) => {
  await page.goto(reportURL);

  const scope = '#view-tests .run-view.active';
  const groups = page.locator(`${scope} .test-summary-group`);
  expect(await groups.count(), 'the fixture must render suites').toBeGreaterThan(0);
  await expect(groups.first()).toBeVisible();

  // A name no test carries, so every row in every suite is hidden and no
  // heading has anything left to head.
  await page.locator(`${scope} .tests-filter`).fill('zzz-no-such-test');
  await expect(
    page.locator(`${scope} .test-summary:visible`),
    'the precondition: the filter must have emptied the tree',
  ).toHaveCount(0);
  await expect(
    page.locator(`${scope} .test-summary-group:visible`),
    'so no suite heading may be left behind',
  ).toHaveCount(0);

  await page.locator(`${scope} .tests-filter`).fill('');
  await expect(groups.first(), 'and they come back when the rows do').toBeVisible();
});

// A test's tail screenshot is emitted between rows rather than inside one
// (A2), which put it outside everything the filters ever touched: a hidden
// test left a 200px picture behind in the tree with no row to belong to.
test('a filtered-out test takes its screenshots with it', async ({ page }) => {
  await page.goto(reportURL);

  const scope = '#view-tests .run-view.active';
  const tails = page.locator(`${scope} img.screenshot-tail`);
  const visibleTails = () => page.locator(`${scope} img.screenshot-tail:visible`).count();

  const total = await tails.count();
  expect(total, 'the fixture must render tail screenshots').toBeGreaterThan(0);
  expect(await visibleTails()).toBe(total);

  // The precondition that makes this more than a one-sibling check:
  // `TestScreenshotFlow` emits a test's *last three* screenshots, so a test
  // with several is preceded by several, and a fix that walked back one
  // sibling would leave the outer ones on screen. The fixture must contain
  // such a run or this gate cannot see that difference.
  const longestRun = await page.evaluate((selector) => {
    const rows = [...document.querySelectorAll(`${selector} .test-summary`)];
    return Math.max(...rows.map((row) => {
      let n = 0;
      let sibling = row.previousElementSibling;
      while (sibling?.classList.contains('screenshot-tail')) { n++; sibling = sibling.previousElementSibling; }
      return n;
    }));
  }, scope);
  expect(longestRun, 'some row must carry more than one tail screenshot')
    .toBeGreaterThan(1);

  // Skipped, because the fixture's screenshots hang off tests that passed or
  // failed — so this hides every row that owns one.
  await page.locator('.pill', { hasText: /^Skipped \(\d+\)$/ }).click();
  expect(
    await visibleTails(),
    'every screenshot belongs to a row the reader asked not to see',
  ).toBe(0);

  await page.locator('.pill', { hasText: /^All \(\d+\)$/ }).click();
  expect(await visibleTails(), 'and they all come back').toBe(total);
});

// Xcode's second number, and the reason it is `aria-live`: it answers to the
// filter, so a reader who cannot see the tree still learns what changed.
test('the executions count answers to the filters', async ({ page }) => {
  await page.goto(reportURL);

  const scope = '#view-tests .run-view.active';
  const count = page.locator(`${scope} .view-toolbar-count`);

  // The fixture's parameterized row ran three times and its retried row twice,
  // so the run holds more executions than tests — the case this figure exists
  // for, asserted before it is filtered.
  await expect(count).toHaveText('9 executions');
  await expect(
    page.locator(`${scope} .test-summary[data-runs]`),
    'the rows that account for the difference must say so',
  ).toHaveCount(2);

  await page.locator('.pill', { hasText: /^Skipped \(\d+\)$/ }).click();
  await expect(count, 'one skipped test that ran once').toHaveText('1 execution');

  await page.locator(`${scope} .tests-filter`).fill('nothing matches this');
  await expect(count, 'and a filter that selects nothing states nothing')
    .toHaveText('0 executions');
});

// ---- The log filter -----------------------------------------------------
//
// Possible at all because A3b renders the log in the page. Behind the iframe
// it replaces, the log was a `file://` sibling or a `data:` URI — a foreign
// origin either way — so no control in this page could have read a line of it,
// which is why A3a's Logs toolbar carried an inert label.
test('the log filter narrows the log to matching lines', async ({ page }) => {
  await page.goto(reportURL);
  await page.locator('#tab-logs').click();

  const body = page.locator('#view-logs .run-view.active .log-body');
  const count = page.locator('#view-logs .run-view.active .view-toolbar-count');

  const lines = (await body.textContent())!.replace(/\n$/, '').split('\n');
  expect(lines.length, 'the fixture must render a log with lines in it')
    .toBeGreaterThan(1);
  await expect(count).toHaveText(`${lines.length} lines`);

  await page.locator('#view-logs .run-view.active .log-filter').fill('line two');
  await expect(body, 'only the matching line survives').toHaveText(/line two/);
  expect((await body.textContent())!.split('\n').filter(Boolean))
    .toHaveLength(1);
  await expect(count, 'and the toolbar states the narrowing')
    .toHaveText(`1 of ${lines.length} lines`);

  await page.locator('#view-logs .run-view.active .log-filter').fill('');
  expect((await body.textContent())!.replace(/\n$/, '').split('\n'))
    .toHaveLength(lines.length);
  await expect(count).toHaveText(`${lines.length} lines`);
});

// The failure digest (#439, A1). Its jump is the one piece of the summary
// header that is behaviour rather than markup, and it has four things to undo
// before the row is on screen — none of which a rendered-HTML assertion can
// see.
test('a digest jump expands the failing test it names', async ({ page }) => {
  await page.goto(reportURL);

  const jump = page.locator('.digest-jump').first();
  const name = (await jump.textContent())?.trim();
  expect(name, 'the fixture must render a failure digest').toBeTruthy();

  const uuid = await jump.getAttribute('data-target');
  const disclosure = page.locator(`#activities-${uuid}, #iterations-${uuid}`).first();
  await expect(disclosure, 'the test starts collapsed').toBeHidden();

  await jump.click();

  await expect(disclosure, 'the jump must expand the test').toBeVisible();
  await expect(
    page.locator('#view-tests .run-view.active .list-item.selected').first(),
    'the jump must select the row it scrolled to',
  ).toContainText(name!);
});

// A digest row for a test the active filter has hidden still has to reach it.
test('a digest jump reveals a row the filter has hidden', async ({ page }) => {
  await page.goto(reportURL);

  // "Passed" hides every failing row, which is every row the digest lists.
  await page.locator('.pill', { hasText: /^Passed \(\d+\)$/ }).click();

  const jump = page.locator('.digest-jump').first();
  const uuid = await jump.getAttribute('data-target');
  const row = page.locator(`#activities-${uuid}, #iterations-${uuid}`).first()
    .locator('xpath=ancestor::div[contains(@class,"test-summary")][1]');
  await expect(row, 'the Passed filter must have hidden the failing row').toBeHidden();

  await jump.click();
  await expect(row, 'the jump must reveal it anyway').toBeVisible();
});

// …and the toolbar has to say so. Revealing the row is half the answer: the
// count beside the pills is `aria-live`, so it is the whole of the notice a
// screen-reader user gets that the pane changed. Left at the figure the filter
// wrote, it announces nothing while a row appears, and states a total the
// reader beside them can disprove by counting the screen.
//
// Summed from the rows rather than pinned to a literal, because the claim is
// an invariant — the toolbar answers for what is visible — and a literal would
// be a second fixture-dependent number to maintain beside the pill labels.
test('a digest jump keeps the executions count level with the rows on screen', async ({ page }) => {
  await page.goto(reportURL);

  const scope = '#view-tests .run-view.active';
  const count = page.locator(`${scope} .view-toolbar-count`);
  const label = (executions: number) =>
    executions === 1 ? '1 execution' : `${executions} executions`;
  const executionsOnScreen = () =>
    page.locator(`${scope} .test-summary:visible`).evaluateAll((rows) =>
      rows.reduce(
        (sum, row) => sum + (parseInt(row.getAttribute('data-runs') ?? '', 10) || 1),
        0,
      ));

  // "Passed" hides every failing row, which is every row the digest lists.
  await page.locator('.pill', { hasText: /^Passed \(\d+\)$/ }).click();
  const filtered = await executionsOnScreen();
  expect(filtered, 'the fixture must leave passing rows on screen').toBeGreaterThan(0);
  await expect(count, 'the filter states its own figure').toHaveText(label(filtered));

  await page.locator('.digest-jump').first().click();

  const revealed = await executionsOnScreen();
  expect(
    revealed,
    'the jump must have put a row the filter hid back on screen, or this asserts nothing',
  ).toBeGreaterThan(filtered);
  await expect(
    count,
    'so the count must follow the pane, not the pills that no longer describe it',
  ).toHaveText(label(revealed));
});

// The narrow layout's scroll lock (#439, A2). Below 700px `#container` is a
// column, so the tree is sized on the block axis by a flex item's automatic
// minimum — its content's height. Without `min-height: 0` the list grew to
// hold every row (measured: 376px of pane hanging 192px below a 500px
// viewport) instead of scrolling inside its share, and because `body` sets
// `overflow: hidden` that overflow was not merely unscrolled but unreachable.
//
// 500px of viewport height rather than a phone's 812: the assertion has to be
// about the layout rule, not about whether this fixture's five tests happen to
// be taller than a particular screen. At 812 the synthetic report overflows by
// five pixels and the test would pass on a broken build.
//
// Scrolled with the wheel, not `scrollIntoView`. A programmatic scroll moves
// an `overflow: hidden` box perfectly well, which is exactly why the bug
// survived this long: the row is reachable by script and unreachable by the
// person reading the report. The wheel is what a reader has.
test('the last test row can be scrolled to at 375px', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 500 });
  await page.goto(reportURL);

  const rows = page.locator('#view-tests .run-view.active .test-summary > p.list-item');
  expect(await rows.count(), 'the fixture must render test rows').toBeGreaterThan(0);

  const geometry = await page.locator('#view-tests .run-view.active .tests').evaluate((el) => ({
    bottom: el.getBoundingClientRect().bottom,
    scrollHeight: el.scrollHeight,
    clientHeight: el.clientHeight,
    viewport: document.documentElement.clientHeight,
  }));

  // The pane has to live inside the window. When it does not, the rows past
  // the fold are behind `overflow: hidden` with nothing able to scroll them.
  expect(
    geometry.bottom,
    'the test list hangs below the viewport instead of scrolling inside it',
  ).toBeLessThanOrEqual(geometry.viewport + 1);

  // …and the rows have to be inside *its* scrollable overflow, not spilled.
  expect(
    geometry.scrollHeight,
    'the rows must overflow the list, which is the thing that scrolls',
  ).toBeGreaterThan(geometry.clientHeight);

  await page.mouse.move(180, geometry.bottom - 20);
  for (let i = 0; i < 12; i++) await page.mouse.wheel(0, 200);

  await expect(
    rows.last(),
    'the last row must come on screen for a reader with a wheel',
  ).toBeInViewport();
});

// The Logs tab gets the column to itself (#439, A2). The summary band
// describes the test run and says nothing about the log, so it stands down
// while the log is showing — and has to come back, at both widths, because a
// header that only ever disappears is a worse bug than one that never moves.
for (const width of [1440, 375]) {
  test(`the summary header stands down for the Logs tab at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 812 });
    await page.goto(reportURL);

    const summary = page.locator('#run-summary');
    const logs = page.locator('#view-logs');
    await expect(summary, 'the band starts in the layout').toBeVisible();

    await page.locator('#tab-logs').click();
    await expect(summary, 'Logs must reclaim the band').toBeHidden();
    await expect(logs, 'the log must take its place').toBeVisible();

    await page.locator('#tab-tests').click();
    await expect(summary, 'Tests must put the band back').toBeVisible();
  });
}

test('arrow keys move the selection', async ({ page }) => {
  await page.goto(reportURL);

  await page.locator('#view-tests .run-view.active .test-summary').first().click();
  const before = await page.locator('#view-tests .run-view.active .list-item.selected').first().textContent();

  await page.keyboard.press('ArrowDown');
  const after = await page.locator('#view-tests .run-view.active .list-item.selected').first().textContent();

  expect(after, 'ArrowDown must move the selection').not.toBe(before);
});

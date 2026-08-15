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

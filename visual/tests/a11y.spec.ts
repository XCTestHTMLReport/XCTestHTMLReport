import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const reportURL = pathToFileURL(resolve(__dirname, '../fixtures/report.html')).href;

// The gate was held open (GATING_IMPACTS = []) from #461 until #462, because
// the first real run found six uncorrected violations and a spec cannot
// assert a clean result that does not exist yet. #462 cleared all six —
// image-alt (critical, 6 nodes), frame-title (serious), heading-order,
// landmark-one-main, region and empty-heading — so the gate is closed again
// and any new critical or serious finding fails the build.
//
// Moderate and minor stay informational rather than gating. That is the
// level #462 prescribed, and it keeps the failure mode proportionate: a
// missing alt or an unnamed frame blocks a merge, a debatable landmark
// question gets logged for a human to weigh.
const GATING_IMPACTS: string[] = ['critical', 'serious'];

// A rule that only fires on a page in a particular state is only as good as
// that state. `scrollable-region-focusable` — the rule that caught the tests
// tree needing a `tabindex` (#439, A2) — analyses a region only if it actually
// overflows, and before A2's taller rows this fixture cleared the default
// viewport by seven pixels. The rule was live in the spec and blind in fact,
// and nothing said so: the gate went green either way.
//
// Two things are needed to close that, and asserting the overflow is only the
// second of them.
//
// First the layout has to settle, because this fixture's does not settle on
// `load`. It carries four `img.screenshot-tail` in the tree, all `loading=
// "lazy"` and all pointing into a `.xcresult` that is not there. A deferred
// image box is 2px until its load is attempted and 20px once it has failed and
// the broken-image placeholder takes its place, so the tree measures 373px or
// 426px depending on whether four loads happened to resolve first — 0px of
// overflow or 53px, from the same file. Under a parallel run it was the wrong
// one about a fifth of the time, which means axe was analysing a tree with no
// scrollable region at all on those runs and this gate could not have caught a
// missing `tabindex` if it tried.
//
// Then assert. Waiting alone would leave the seven-pixel problem intact, and
// asserting alone would just make a real race into a flaky test.
async function settleImages(page: import('@playwright/test').Page) {
  await page.waitForFunction(() => [...document.images]
    .filter((img) => img.getClientRects().length > 0)
    .every((img) => img.complete));
}

async function treeGeometryAtAxeViewport(page: import('@playwright/test').Page) {
  return page.evaluate(() => {
    const tree = document.querySelector('#view-tests .run-view.active .tests');
    if (!tree) return null;
    return {
      overflow: tree.scrollHeight - tree.clientHeight,
      scrollHeight: tree.scrollHeight,
      clientHeight: tree.clientHeight,
      viewport: `${window.innerWidth}x${window.innerHeight}`,
      rows: tree.querySelectorAll('p.list-item').length,
    };
  });
}

async function expectNoGatingViolations(page: import('@playwright/test').Page, state: string) {
  const results = await new AxeBuilder({ page }).analyze();

  const gating = results.violations.filter((v) => GATING_IMPACTS.includes(v.impact ?? ''));
  const informational = results.violations.filter((v) => !GATING_IMPACTS.includes(v.impact ?? ''));

  if (informational.length) {
    console.log(
      `Non-gating violations (${state}; triage onto #440):\n`
        + informational.map((v) => `  [${v.impact}] ${v.id}: ${v.help}`).join('\n'),
    );
  }

  expect(
    gating.map((v) => `[${v.impact}] ${v.id}: ${v.help} (${v.nodes.length} nodes)`),
    `critical/serious accessibility violations (${state})`,
  ).toEqual([]);
}

test('reports no critical or serious accessibility violations', async ({ page }) => {
  await page.goto(reportURL);
  await settleImages(page);

  const tree = await treeGeometryAtAxeViewport(page);
  expect(tree, 'the fixture must render a tests pane for axe to analyse').not.toBeNull();
  expect(
    tree!.overflow,
    'the tests pane must overflow at the axe viewport, or scrollable-region-focusable is '
      + `not exercised and this gate cannot speak to it — measured ${JSON.stringify(tree)}`,
  ).toBeGreaterThan(0);

  await expectNoGatingViolations(page, 'the Tests view, as opened');
});

// A3a (#439) turned three permanent panes into surfaces that come and go, and
// axe only sees what is in the DOM when it runs. Before, the device sidebar and
// the attachment pane were always rendered and therefore always analysed; a
// gate that only ever saw the opening state would now be blind to the picker's
// panel, to the sheet, and to the whole Logs view — a coverage loss disguised
// as a clean run.
//
// Each state below asserts its own precondition first, for the same reason the
// tree's overflow is asserted above: a state that failed to open is a state
// axe passes trivially, and nothing in the result would say so.
const states: [string, (page: import('@playwright/test').Page) => Promise<void>][] = [
  ['the device picker, open', async (page) => {
    await page.locator('#device-picker summary').click();
    await expect(
      page.locator('.picker-panel .device-option').first(),
      'the picker must actually be open, or axe analyses a closed disclosure',
    ).toBeVisible();
  }],
  ['the attachment sheet, open', async (page) => {
    await page.locator('.attachment .preview-button').first().evaluate((el: HTMLElement) => {
      el.closest('.attachments')!.setAttribute('style', 'display: block');
      el.click();
    });
    await expect(
      page.locator('#attachment-sheet'),
      'the sheet must be in the layout, or axe analyses a report with no sheet at all',
    ).toBeVisible();
  }],
  ['the Logs view', async (page) => {
    await page.locator('#tab-logs').click();
    await expect(
      page.locator('#view-logs .run-view.active .log-body'),
      'the log must be showing, or this state is the Tests view again',
    ).toBeVisible();
  }],
  // A3b's controls are in the layout from the start, so the opening state
  // already analyses them. What it does not analyse is the page they *produce*:
  // a tree narrowed to one bucket and one name, where rows and whole suites
  // carry `display: none` and the live count has been rewritten by script.
  // That is a different document, and axe only ever sees the one in front of
  // it.
  ['the Tests view, filtered', async (page) => {
    await page.locator('.pill', { hasText: /^Expected failures \(\d+\)$/ }).click();
    await page.locator('#view-tests .run-view.active .tests-filter').fill('test');
    await expect(
      page.locator('#view-tests .run-view.active .test-summary:visible'),
      'the filters must have left rows showing, or this state is an empty pane',
    ).not.toHaveCount(0);
    const [shown, total] = await page.evaluate(() => {
      const rows = [...document.querySelectorAll('#view-tests .run-view.active .test-summary')];
      return [rows.filter((r) => (r as HTMLElement).offsetParent !== null).length, rows.length];
    });
    expect(shown, 'and must have hidden some, or nothing was filtered').toBeLessThan(total);
  }],
  ['the Logs view, filtered', async (page) => {
    await page.locator('#tab-logs').click();
    const body = page.locator('#view-logs .run-view.active .log-body');
    const before = (await body.textContent())!.length;
    await page.locator('#view-logs .run-view.active .log-filter').fill('line two');
    expect(
      (await body.textContent())!.length,
      'the filter must have narrowed the log, or this state is the log entire',
    ).toBeLessThan(before);
  }],
];

for (const [state, open] of states) {
  test(`reports no critical or serious accessibility violations: ${state}`, async ({ page }) => {
    await page.goto(reportURL);
    await settleImages(page);
    await open(page);
    await expectNoGatingViolations(page, state);
  });
}

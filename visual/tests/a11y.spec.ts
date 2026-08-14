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

test('reports no critical or serious accessibility violations', async ({ page }) => {
  await page.goto(reportURL);
  const results = await new AxeBuilder({ page }).analyze();

  const gating = results.violations.filter((v) => GATING_IMPACTS.includes(v.impact ?? ''));
  const informational = results.violations.filter((v) => !GATING_IMPACTS.includes(v.impact ?? ''));

  if (informational.length) {
    console.log(
      'Non-gating violations (triage onto #440):\n'
        + informational.map((v) => `  [${v.impact}] ${v.id}: ${v.help}`).join('\n'),
    );
  }

  expect(
    gating.map((v) => `[${v.impact}] ${v.id}: ${v.help} (${v.nodes.length} nodes)`),
    'critical/serious accessibility violations',
  ).toEqual([]);
});

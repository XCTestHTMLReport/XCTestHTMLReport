import { test, expect } from '@playwright/test';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const reportURL = pathToFileURL(resolve(__dirname, '../fixtures/report.html')).href;

test('the failed filter hides passing tests', async ({ page }) => {
  await page.goto(reportURL);

  const visibleRows = () => page.locator('.run.active .test-summary:visible').count();

  const all = await visibleRows();
  expect(all, 'fixture must render test rows').toBeGreaterThan(0);

  await page.locator('li', { hasText: /^Failed \(\d+\)$/ }).click();
  const failed = await visibleRows();

  expect(failed, 'filtering to Failed must hide rows').toBeLessThan(all);
  expect(failed, 'the fixture has failing tests, so some rows must remain').toBeGreaterThan(0);
});

test('arrow keys move the selection', async ({ page }) => {
  await page.goto(reportURL);

  await page.locator('.run.active .test-summary').first().click();
  const before = await page.locator('.run.active .list-item.selected').first().textContent();

  await page.keyboard.press('ArrowDown');
  const after = await page.locator('.run.active .list-item.selected').first().textContent();

  expect(after, 'ArrowDown must move the selection').not.toBe(before);
});

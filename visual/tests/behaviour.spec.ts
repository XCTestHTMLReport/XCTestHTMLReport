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
    page.locator('.run.active .list-item.selected').first(),
    'the jump must select the row it scrolled to',
  ).toContainText(name!);
});

// A digest row for a test the active filter has hidden still has to reach it.
test('a digest jump reveals a row the filter has hidden', async ({ page }) => {
  await page.goto(reportURL);

  // "Passed" hides every failing row, which is every row the digest lists.
  await page.locator('li', { hasText: /^Passed \(\d+\)$/ }).click();

  const jump = page.locator('.digest-jump').first();
  const uuid = await jump.getAttribute('data-target');
  const row = page.locator(`#activities-${uuid}, #iterations-${uuid}`).first()
    .locator('xpath=ancestor::div[contains(@class,"test-summary")][1]');
  await expect(row, 'the Passed filter must have hidden the failing row').toBeHidden();

  await jump.click();
  await expect(row, 'the jump must reveal it anyway').toBeVisible();
});

test('arrow keys move the selection', async ({ page }) => {
  await page.goto(reportURL);

  await page.locator('.run.active .test-summary').first().click();
  const before = await page.locator('.run.active .list-item.selected').first().textContent();

  await page.keyboard.press('ArrowDown');
  const after = await page.locator('.run.active .list-item.selected').first().textContent();

  expect(after, 'ArrowDown must move the selection').not.toBe(before);
});

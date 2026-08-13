import { test, expect, type Page } from '@playwright/test';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const reportURL = pathToFileURL(resolve(__dirname, '../fixtures/report.html')).href;

/** Every custom property declared on :root, read from the live stylesheet.
 *  Walks nested grouping rules (e.g. @media, @supports, @layer) recursively
 *  so a :root inside @media (prefers-color-scheme: dark) is not missed. */
async function declaredTokens(page: Page): Promise<string[]> {
  return page.evaluate(() => {
    const names = new Set<string>();
    const walk = (rules: CSSRuleList) => {
      for (const rule of Array.from(rules)) {
        if (rule instanceof CSSStyleRule) {
          if (rule.selectorText.split(',').some((s) => s.trim() === ':root')) {
            for (const prop of Array.from(rule.style)) {
              if (prop.startsWith('--')) names.add(prop);
            }
          }
        } else if (rule instanceof CSSGroupingRule) {
          walk(rule.cssRules);
        }
      }
    };
    for (const sheet of Array.from(document.styleSheets)) {
      walk(sheet.cssRules);
    }
    return Array.from(names);
  });
}

test('every declared token resolves to a non-empty value', async ({ page }) => {
  await page.goto(reportURL);
  const tokens = await declaredTokens(page);

  expect(tokens.length, 'the stylesheet must declare custom properties').toBeGreaterThan(0);

  for (const token of tokens) {
    const value = await page.evaluate(
      (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim(),
      token,
    );
    expect(value, `${token} resolves to nothing`).not.toBe('');
  }
});

test('no rule references an undeclared token', async ({ page }) => {
  await page.goto(reportURL);
  const declared = new Set(await declaredTokens(page));

  const referenced: string[] = await page.evaluate(() => {
    const names = new Set<string>();
    const walk = (rules: CSSRuleList) => {
      for (const rule of Array.from(rules)) {
        if (rule instanceof CSSStyleRule) {
          for (const prop of Array.from(rule.style)) {
            const value = rule.style.getPropertyValue(prop);
            for (const match of value.matchAll(/var\(\s*(--[\w-]+)/g)) {
              names.add(match[1]);
            }
          }
        } else if (rule instanceof CSSGroupingRule) {
          walk(rule.cssRules);
        }
      }
    };
    for (const sheet of Array.from(document.styleSheets)) {
      walk(sheet.cssRules);
    }
    return Array.from(names);
  });

  const undeclared = referenced.filter((name) => !declared.has(name));
  expect(undeclared, `referenced but never declared: ${undeclared.join(', ')}`).toEqual([]);
});

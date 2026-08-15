import { test, expect, type Page } from '@playwright/test';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const reportURL = pathToFileURL(resolve(__dirname, '../fixtures/report.html')).href;
const multiURL = pathToFileURL(resolve(__dirname, '../fixtures/report-multi.html')).href;

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

  // Reads `rule.cssText` rather than iterating `rule.style` longhand-by-
  // longhand: a shorthand that contains a `var()` (e.g. `border: 1px solid
  // var(--color-border-strong)`) is stored by Chromium as a *pending-
  // substitution value*, so every expanded longhand it covers serialises to
  // `""` and the reference is invisible to `rule.style.getPropertyValue`.
  // `cssText` still carries the literal `var(...)` text regardless of
  // shorthand expansion, so the regex scan below sees it.
  const referenced: string[] = await page.evaluate(() => {
    const names = new Set<string>();
    const walk = (rules: CSSRuleList) => {
      for (const rule of Array.from(rules)) {
        if (rule instanceof CSSStyleRule) {
          for (const match of rule.style.cssText.matchAll(/var\(\s*(--[\w-]+)/g)) {
            names.add(match[1]);
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

/** WCAG 2.1 relative luminance. */
function luminance(rgb: [number, number, number]): number {
  const [r, g, b] = rgb.map((channel) => {
    const c = channel / 255;
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrastRatio(a: [number, number, number], b: [number, number, number]): number {
  const [light, dark] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (light + 0.05) / (dark + 0.05);
}

/**
 * Resolved foreground/background pairs for every element that carries text.
 * Discovered from the live cascade rather than a hand-written matrix: a fixed
 * list stops covering a pairing the moment the redesign introduces one.
 */
async function textPairs(page: Page) {
  return page.evaluate(() => {
    const parse = (value: string): [number, number, number] | null => {
      const match = value.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
      return match ? [Number(match[1]), Number(match[2]), Number(match[3])] : null;
    };
    const effectiveBackground = (element: Element): [number, number, number] => {
      let node: Element | null = element;
      while (node) {
        const nodeStyle = getComputedStyle(node);
        // A masked element's `background-color` is an icon fill (e.g.
        // `mask-image` + `background-color: currentColor`, the single-colour
        // tintable-icon pattern), not a rectangle painted behind text — the
        // mask clips it to the glyph's silhouette, so there is no surface
        // here for text to sit on. Skip it and keep walking for the real
        // background, exactly as if this element painted nothing.
        const masked = nodeStyle.maskImage !== 'none' || nodeStyle.webkitMaskImage !== 'none';
        if (!masked) {
          const bg = parse(nodeStyle.backgroundColor);
          const alpha = nodeStyle.backgroundColor.match(/rgba\([^)]*,\s*0\)/);
          if (bg && !alpha) return bg;
        }
        node = node.parentElement;
      }
      return [255, 255, 255];
    };

    const results: { selector: string; fg: number[]; bg: number[]; size: number; bold: boolean }[] = [];
    for (const element of Array.from(document.querySelectorAll('body *'))) {
      const text = Array.from(element.childNodes)
        .filter((n) => n.nodeType === Node.TEXT_NODE)
        .map((n) => n.textContent?.trim() ?? '')
        .join('');
      if (!text) continue;
      const style = getComputedStyle(element);
      if (style.visibility === 'hidden' || style.display === 'none') continue;
      const fg = parse(style.color);
      if (!fg) continue;
      results.push({
        selector: element.tagName.toLowerCase() + (element.className ? `.${element.className}` : ''),
        fg,
        bg: effectiveBackground(element),
        size: parseFloat(style.fontSize),
        bold: Number(style.fontWeight) >= 700,
      });
    }
    return results;
  });
}

/**
 * Open every surface the shell can show before measuring (#439, A3a).
 *
 * `textPairs` reads the live cascade, which is what makes it survive a
 * redesign — but it can only read what is in the layout, and A3a turned three
 * permanent panes into surfaces that come and go. The picker's panel sits
 * inside a closed `<details>` and the attachment sheet is not in the layout
 * until something is in it, so on the opening state this walk sees neither:
 * a colour used only on a picker option would go unmeasured while the gate
 * reported green.
 *
 * Each step asserts what it opened, for the same reason the axe gate does —
 * an open that silently failed is a state the check passes trivially.
 */
async function openEveryShellSurface(page: Page) {
  await page.locator('#device-picker summary').click();
  await expect(page.locator('.picker-panel .device-option').first()).toBeVisible();

  await page.locator('.attachment .preview-button').first().evaluate((el: HTMLElement) => {
    el.closest('.attachments')!.setAttribute('style', 'display: block');
    el.click();
  });
  await expect(page.locator('#attachment-sheet')).toBeVisible();
}

// Both fixtures, because one of them cannot show what the other does: the run
// number an option carries is rendered only when a report holds several runs,
// so the single-run fixture has no element to measure it on.
for (const [fixture, url] of [['single-run', reportURL], ['multi-run', multiURL]] as const) {
  for (const scheme of ['light', 'dark'] as const) {
    test(`text clears WCAG AA contrast floors in ${scheme} mode (${fixture})`, async ({ page }) => {
      await page.emulateMedia({ colorScheme: scheme });
      await page.goto(url);
      await openEveryShellSurface(page);

      const pairs = await textPairs(page);
      expect(pairs.length, 'no text elements found — the fixture rendered nothing').toBeGreaterThan(0);

      const failures: string[] = [];
      for (const pair of pairs) {
        // WCAG "large text": 18.66px bold, or 24px regular.
        const large = pair.size >= 24 || (pair.bold && pair.size >= 18.66);
        const floor = large ? 3.0 : 4.5;
        const ratio = contrastRatio(pair.fg as [number, number, number], pair.bg as [number, number, number]);
        if (ratio < floor) {
          failures.push(`${pair.selector}: ${ratio.toFixed(2)}:1 < ${floor}:1`);
        }
      }
      expect(failures, failures.join('\n')).toEqual([]);
    });
  }
}

test('dark mode actually changes the palette', async ({ page }) => {
  const surfaceIn = async (scheme: 'light' | 'dark') => {
    await page.emulateMedia({ colorScheme: scheme });
    await page.goto(reportURL);
    return page.evaluate(() =>
      getComputedStyle(document.documentElement).getPropertyValue('--color-surface').trim(),
    );
  };
  expect(await surfaceIn('dark')).not.toBe(await surfaceIn('light'));
});

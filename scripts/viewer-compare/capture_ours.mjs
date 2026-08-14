// Captures this checkout's rendered report headlessly, in the grid the Xcode
// side is framed to match: summary / tests / logs, at 1440 in both appearances
// and at 375 in light.
//
// Driven by viewer_compare.sh, which has already built the binary, rendered the
// fixture and put an HTTP server in front of it. Run standalone with:
//
//   VC_OUT=<dir> VC_URL=http://127.0.0.1:8899/index.html \
//     node scripts/viewer-compare/capture_ours.mjs
//
// Playwright is not a dependency of this directory. It is borrowed from
// visual/, whose package-lock.json already pins the version CI uses, so the two
// browser layers cannot drift apart and this tool adds no second lockfile.

import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import fs from 'node:fs';
import path from 'node:path';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, '..', '..');
const VISUAL = path.join(REPO, 'visual');

const OUT = process.env.VC_OUT;
const URL = process.env.VC_URL;
if (!OUT || !URL) {
    console.error('capture_ours.mjs: VC_OUT and VC_URL must both be set');
    process.exit(2);
}

// Resolve from visual/node_modules rather than from this file's own directory,
// which has no node_modules and is not meant to grow one.
//
// `playwright`, not `playwright-core`: visual/package-lock.json hoists a SECOND
// playwright-core to the top of that tree (a transitive dependency of
// @axe-core/playwright, on a looser range), and it is a different version from
// the one @playwright/test runs — different enough to want a browser build that
// `npx playwright install` never fetched. Going through `playwright` lands on
// the same nested core, and therefore the same browser, that the visual suite
// and CI use.
const requireFromVisual = createRequire(path.join(VISUAL, 'package.json'));
let chromium;
let playwrightVersion = 'unknown';
try {
    ({ chromium } = requireFromVisual('playwright'));
    playwrightVersion = requireFromVisual('playwright/package.json').version;
} catch (err) {
    console.error(
        `capture_ours.mjs: could not load playwright from ${VISUAL}/node_modules.\n` +
            `Run \`npm ci\` in ${VISUAL} first (viewer_compare.sh does this for you).\n` +
            String(err)
    );
    process.exit(2);
}

// 2x everywhere, because `screencapture` on a Retina display hands back 2x and
// a comparison page that mixes scales makes the two sides look like they differ
// in weight when they only differ in sampling.
const DEVICE_SCALE_FACTOR = 2;

const COMBOS = [
    { width: 1440, height: 900, scheme: 'light' },
    { width: 1440, height: 900, scheme: 'dark' },
    { width: 375, height: 812, scheme: 'light' },
];

// `clip` decides what part of the viewport a view is worth showing:
//   header     — the summary band alone, the thing being compared to Xcode's
//                summary pane; framing it whole keeps the comparison honest
//                when its height changes between runs.
//   viewport   — the window as it loads, the like-for-like against an Xcode
//                window pinned to the same logical size.
//   belowHeader — the content region, so a summary that grows does not push
//                the test tree out of the shot and make it look empty.
const VIEWS = [
    { name: 'summary', tab: 'Tests', clip: 'header' },
    { name: 'overview', tab: 'Tests', clip: 'viewport' },
    { name: 'tests', tab: 'Tests', clip: 'belowHeader' },
    { name: 'logs', tab: 'Logs', clip: 'viewport' },
];

async function selectTab(page, label) {
    const tab = page.locator('#test-log-toolbar li', { hasText: new RegExp(`^${label}$`) }).first();
    await tab.click();
    // The Logs pane swaps in an iframe; give it a beat to lay out before the
    // shutter, or the shot catches an empty frame that reads as a bug.
    await page.waitForTimeout(800);
}

async function clipFor(page, view, combo) {
    if (view.clip === 'viewport') return undefined;
    const header = await page.locator('header').boundingBox();
    if (!header) throw new Error(`no <header> found for view ${view.name}`);
    if (view.clip === 'header') {
        return { x: 0, y: 0, width: combo.width, height: Math.ceil(header.height) };
    }
    const y = Math.floor(header.height);
    return { x: 0, y, width: combo.width, height: Math.max(1, combo.height - y) };
}

// Values a comparison page wants in prose next to the shots, and which are
// cheaper to read from the DOM than to eyeball off a PNG later.
async function probe(page) {
    const text = async (sel) => page.locator(sel).first().innerText().catch(() => null);
    const count = async (sel) => page.locator(sel).count().catch(() => 0);
    const header = await page.locator('header').boundingBox();
    return {
        headerHeightCss: header ? Math.round(header.height) : null,
        donut: await text('.donut-center'),
        summaryMeta: await text('.summary-meta'),
        failureDigestRows: await count('.failure-digest li'),
        deviceRows: await count('.device-row-name'),
    };
}

const browser = await chromium.launch({ headless: true });
const shots = [];
let probes = {};

for (const combo of COMBOS) {
    const tag = `${combo.width}-${combo.scheme}`;
    const page = await browser.newPage({
        viewport: { width: combo.width, height: combo.height },
        deviceScaleFactor: DEVICE_SCALE_FACTOR,
        colorScheme: combo.scheme,
    });

    const httpErrors = [];
    page.on('response', (r) => {
        // /favicon.ico is requested by the browser, not by the report, and is
        // not shipped; it is the one 404 that means nothing.
        if (r.status() >= 400 && !r.url().endsWith('/favicon.ico')) {
            httpErrors.push(`${r.status()} ${r.url()}`);
        }
    });
    const pageErrors = [];
    page.on('pageerror', (e) => pageErrors.push(String(e.message)));

    await page.goto(URL, { waitUntil: 'load' });
    await page.waitForTimeout(500);
    probes[tag] = { ...(await probe(page)), httpErrors, pageErrors };

    let currentTab = 'Tests';
    for (const view of VIEWS) {
        if (view.tab !== currentTab) {
            await selectTab(page, view.tab);
            currentTab = view.tab;
        }
        const file = `ours-${view.name}-${tag}.png`;
        const clip = await clipFor(page, view, combo);
        await page.screenshot({ path: path.join(OUT, file), clip });
        shots.push({
            file,
            side: 'ours',
            view: view.name,
            width: combo.width,
            height: combo.height,
            colorScheme: combo.scheme,
            deviceScaleFactor: DEVICE_SCALE_FACTOR,
            clip: view.clip,
            automated: true,
        });
        console.log(`ours: ${file}`);
    }
    await page.close();
}

await browser.close();

// A 404 here means the shots are of a report whose attachments did not load —
// which looks like a rendering regression and is usually a serving mistake.
// Say so rather than leaving it for whoever reads the manifest later.
const broken = Object.entries(probes).filter(([, p]) => p.httpErrors.length > 0);
for (const [tag, p] of broken) {
    console.warn(`ours: WARNING ${tag} had ${p.httpErrors.length} failed request(s):`);
    for (const line of p.httpErrors.slice(0, 5)) console.warn(`  ${line}`);
}

fs.writeFileSync(
    path.join(OUT, 'ours-shots.json'),
    JSON.stringify(
        {
            tool: `playwright ${playwrightVersion} (bundled Chromium, headless)`,
            url: URL,
            deviceScaleFactor: DEVICE_SCALE_FACTOR,
            colorScheme: 'emulated via prefers-color-scheme; the report has no in-page theme toggle',
            probes,
            shots,
        },
        null,
        2
    ) + '\n'
);
console.log(`ours: ${shots.length} shots -> ${OUT}`);

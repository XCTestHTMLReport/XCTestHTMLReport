import { defineConfig } from '@playwright/test';

// The suite reads a file the Swift dump test wrote; there is no server and no
// .xcresult involved. Chromium only: these assertions are about token values
// and computed styles, which are engine-independent, so a second engine would
// triple the runtime and assert the same numbers.
export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : 'list',
  use: {
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }],
});

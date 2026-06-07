import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 60000,
  retries: 0,
  reporter: [['html', { open: 'never' }], ['list']],
  fullyParallel: false,
  workers: 1,
  use: {
    baseURL: 'http://localhost:3000/api/v1',
    extraHTTPHeaders: {
      'Content-Type': 'application/json',
    },
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
  ],
});

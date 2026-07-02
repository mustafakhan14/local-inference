import { test, expect } from '@playwright/test';

test.describe('Stack Hub', () => {
  test('hub loads with downloads panel', async ({ page }) => {
    await page.goto('/hub/?tab=downloads');
    await expect(page.locator('h1')).toContainText('Local AI Stack Hub');
    await expect(page.locator('#dl-grid')).toBeVisible();
  });

  test('tab navigation via URL', async ({ page }) => {
    await page.goto('/hub/?tab=status');
    await expect(page.locator('#status')).toHaveClass(/active/);
    await expect(page.locator('#downloads')).not.toHaveClass(/active/);
    await expect(page.locator('#status-grid')).toBeVisible();
  });

  test('terminal tab shows iframe', async ({ page }) => {
    await page.goto('/hub/?tab=terminal');
    await expect(page.locator('#terminal')).toHaveClass(/active/);
    await expect(page.locator('iframe.term')).toBeVisible();
  });

  test('downloads API returns jobs', async ({ request }) => {
    const res = await request.get('/hub/api/downloads');
    expect(res.ok()).toBeTruthy();
    const data = await res.json();
    expect(data.jobs).toHaveLength(3);
    expect(data.jobs.map((j: { id: string }) => j.id)).toContain('fable-agent');
  });

  test('resume queues download', async ({ page, request }) => {
    const res = await request.post('/hub/api/downloads/resume', {
      data: { id: 'fable-agent' },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.queued).toBe(true);

    await page.goto('/hub/?tab=downloads');
    await page.locator('[data-resume="fable-agent"]').click();
    await expect(page.locator('#toast')).toHaveClass(/show/);
  });

  test('hermes chat page', async ({ page }) => {
    await page.goto('/hub/agents/hermes');
    await expect(page.locator('#input')).toBeVisible();
    await expect(page.locator('#send')).toBeVisible();
  });

  test('openclaw chat page', async ({ page }) => {
    await page.goto('/hub/agents/openclaw');
    await expect(page.locator('#input')).toBeVisible();
  });

  test('terminal proxy returns 200', async ({ request }) => {
    const res = await request.get('/hub/terminal/');
    expect(res.status()).toBe(200);
  });
});

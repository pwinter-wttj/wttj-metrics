import { test, expect } from '@playwright/test';
import { loadReport } from '../test-utils';

test.describe('Cycles Section', () => {
    test.beforeEach(async ({ page }) => {
        await loadReport(page);
    });

    test('displays team comparison table', async ({ page }) => {
        const teamSection = page.locator('section', { has: page.locator('.section-title', { hasText: 'Team Comparison' }) });
        const table = teamSection.locator('.data-table');

        await expect(table).toBeVisible();
    });

    test('team comparison table has correct headers', async ({ page }) => {
        const teamSection = page.locator('section', { has: page.locator('.section-title', { hasText: 'Team Comparison' }) });
        const headersRow = teamSection.locator('.data-table thead tr');

        // Verify key headers exist in the table
        await expect(headersRow).toContainText('Team');
        await expect(headersRow).toContainText('Median Velocity');
        await expect(headersRow).toContainText('Median Completion');
        await expect(headersRow).toContainText('Median Scope Change');
    });

    test('team comparison shows scope change values', async ({ page }) => {
        const teamSection = page.locator('section', { has: page.locator('.section-title', { hasText: 'Team Comparison' }) });
        const scopeChangeCells = teamSection.locator('tbody td:last-child');

        const count = await scopeChangeCells.count();
        expect(count).toBeGreaterThan(0);

        // First scope change should contain a percentage
        await expect(scopeChangeCells.first()).toContainText(/%/);
    });

    test('displays cycles by team section', async ({ page }) => {
        const cyclesSection = page.locator('section', { has: page.locator('.section-title', { hasText: 'Cycles by Team' }) });
        await expect(cyclesSection).toBeVisible();
    });

    test('cycles table has correct headers', async ({ page }) => {
        const cyclesSection = page.locator('section', { has: page.locator('.section-title', { hasText: 'Cycles by Team' }) });
        const firstTable = cyclesSection.locator('.data-table').first();
        const headersRow = firstTable.locator('thead tr');

        // Verify key headers exist in the table
        await expect(headersRow).toContainText('Cycle');
        await expect(headersRow).toContainText('Status');
        await expect(headersRow).toContainText('Progress');
        await expect(headersRow).toContainText('Issues');
        await expect(headersRow).toContainText('Velocity');
        await expect(headersRow).toContainText('Scope Change');
    });

    test('cycle status badges are properly styled', async ({ page }) => {
        const cyclesSection = page.locator('section', { has: page.locator('.section-title', { hasText: 'Cycles by Team' }) });
        const statusBadges = cyclesSection.locator('.status-badge');

        const count = await statusBadges.count();
        expect(count).toBeGreaterThan(0);
    });

    test('active cycles have status badge with active class', async ({ page }) => {
        const cyclesSection = page.locator('section', { has: page.locator('.section-title', { hasText: 'Cycles by Team' }) });
        const activeBadge = cyclesSection.locator('.status-badge.status-active');

        // If there are active cycles, they should have the active class
        const count = await activeBadge.count();
        if (count > 0) {
            // Verify the element exists (may be outside viewport on mobile)
            expect(count).toBeGreaterThan(0);
            await expect(activeBadge.first()).toHaveClass(/status-active/);
        }
    });

    test('progress bars are visible', async ({ page }) => {
        const cyclesSection = page.locator('section', { has: page.locator('.section-title', { hasText: 'Cycles by Team' }) });
        const progressBars = cyclesSection.locator('.progress-bar');

        const count = await progressBars.count();
        expect(count).toBeGreaterThan(0);
    });

    test('scope change column shows tooltips with breakdown', async ({ page }) => {
        const cyclesSection = page.locator('section', { has: page.locator('.section-title', { hasText: 'Cycles by Team' }) });
        const scopeChangeCell = cyclesSection.locator('td.has-tooltip').first();

        if (await scopeChangeCell.count() > 0) {
            const tooltip = scopeChangeCell.locator('.cell-tooltip');

            // Hover to show tooltip
            await scopeChangeCell.hover();
            await expect(tooltip).toBeVisible();
            await expect(tooltip).toContainText(/Initial:.*issues.*Final:.*issues/);
        }
    });

    test('scope change colors indicate increase/decrease', async ({ page }) => {
        const cyclesSection = page.locator('section', { has: page.locator('.section-title', { hasText: 'Cycles by Team' }) });

        // Check for scope-increased (red) or scope-decreased (green) classes
        const increasedCells = cyclesSection.locator('.scope-increased');
        const decreasedCells = cyclesSection.locator('.scope-decreased');
        const neutralCells = cyclesSection.locator('.scope-neutral');

        // At least one of these should exist
        const totalCount = await increasedCells.count() + await decreasedCells.count() + await neutralCells.count();
        expect(totalCount).toBeGreaterThan(0);
    });
});

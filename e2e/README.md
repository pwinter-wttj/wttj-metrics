# E2E Tests

End-to-end tests for the WTTJ Metrics HTML report using Playwright.

## Overview

This directory contains 77 Playwright tests that validate the generated HTML dashboard report. These tests ensure the report displays correctly, is accessible, and provides accurate data visualization across different devices and browsers.

## Test Structure

```
e2e/
├── accessibility.spec.ts         # WCAG compliance, keyboard navigation, screen readers
├── bug-tracking.spec.ts          # Bug metrics, resolution rates, MTTR
├── charts.spec.ts                # Chart rendering and data visualization
├── collapsibility.spec.ts        # Section toggle functionality
├── cycles.spec.ts                # Sprint/cycle metrics and tables
├── data-integrity.spec.ts        # Data validation and format checks
├── key-metrics.spec.ts           # Key metrics cards (10 metrics)
├── mobile.spec.ts                # Mobile responsiveness and touch interactions
├── report-structure.spec.ts      # Page structure and sections
├── tooltips.spec.ts              # Tooltip behavior and positioning
├── visual-regression.spec.ts     # Visual snapshots and regression detection
├── test-utils.ts                 # Shared utilities and helpers
└── README.md                     # This file
```

## Running Tests

### Prerequisites

```bash
# Install Node.js dependencies
npm install

# Install Playwright browsers (first time only)
npx playwright install
```

### Commands

```bash
# Run all tests
npm test

# Run specific test file
npx playwright test e2e/key-metrics.spec.ts

# Run tests in headed mode (see browser)
npx playwright test --headed

# Run tests in debug mode
npx playwright test --debug

# Run tests in specific browser
npx playwright test --project=chromium
npx playwright test --project=firefox
npx playwright test --project=webkit

# Show last test report
npx playwright show-report

# Update visual snapshots (when UI changes intentionally)
npx playwright test --update-snapshots
```

## Test Suites

### 1. Accessibility Tests (`accessibility.spec.ts`)
**9 tests** - Ensures WCAG compliance and inclusive design

- Document structure (headings hierarchy)
- Language attribute
- Viewport meta tag
- Image alt text
- Keyboard navigation
- Focus management
- Color contrast
- Table headers
- Status indicators (not color-only)

### 2. Bug Tracking Tests (`bug-tracking.spec.ts`)
**9 tests** - Validates bug metrics and visualizations

- Bug metrics grid layout
- Bug overview cards
- Resolution rate display
- Bug status chart
- Bugs by priority chart
- Bug flow chart
- Bugs by team chart
- Team table with MTTR
- Resolution rate styling (color-coded)

### 3. Charts Tests (`charts.spec.ts`)
**8 tests** - Verifies Chart.js visualizations

- Ticket flow chart
- Transition chart
- Status distribution
- Priority distribution
- Type distribution (7 categories)
- Assignee chart
- Chart titles
- Filter badges

### 4. Collapsibility Tests (`collapsibility.spec.ts`)
**5 tests** - Tests section expand/collapse functionality

- Toggle switches presence
- Click toggle behavior
- Header click behavior
- Chevron rotation
- Multiple sections

### 5. Cycles Tests (`cycles.spec.ts`)
**11 tests** - Validates sprint/cycle data

- Team comparison table
- Table headers
- Scope change values
- Cycles by team section
- Cycle table headers
- Status badges styling
- Active cycle badges
- Progress bars
- Scope change tooltips
- Scope change colors

### 6. Data Integrity Tests (`data-integrity.spec.ts`)
**9 tests** - Ensures data accuracy and formats

- Metric values are numbers
- Percentages (0-100%)
- Completion rates validity
- Cycle progress (0-100)
- Date formats (ISO 8601)
- Non-negative counts
- Non-negative velocity
- Scope change format

### 7. Key Metrics Tests (`key-metrics.spec.ts`)
**5 tests** - Validates 10 key metric cards

- Card count (10 metrics)
- Card structure (value + label)
- Value formatting
- Tooltip on hover
- WIP metric display

**Key Metrics:**
1. Median Cycle Time
2. Median Lead Time
3. Median Review Time (NEW)
4. Weekly Throughput
5. Current WIP
6. Completion Rate
7. Total Open Bugs
8. Total Bugs Created
9. Total Bugs Closed
10. Bug Resolution Rate

### 8. Mobile Tests (`mobile.spec.ts`)
**7 tests** - Mobile responsiveness validation

- Page rendering on mobile
- Metric cards stacking
- Scrollable tables
- Chart resizing
- Toggle functionality
- Font readability
- Touch interactions

### 9. Report Structure Tests (`report-structure.spec.ts`)
**5 tests** - Basic page structure

- Page title
- Main header with date
- Subtitle with generation date
- Main sections presence
- Footer with source info

### 10. Tooltips Tests (`tooltips.spec.ts`)
**5 tests** - Tooltip behavior and styling

- Metric card tooltips
- Table header tooltips
- Scope change tooltips
- Tooltip positioning
- Text color contrast

### 11. Visual Regression Tests (`visual-regression.spec.ts`)
**6 tests** - Screenshot-based regression detection

- Full page capture
- Key metrics section
- Bug tracking section
- Cycles table
- Hover states
- Collapsed sections

## Test Utilities

### `test-utils.ts`

**`loadReport(page)`**
Loads the HTML report for testing. Looks for the report in:
1. `report/report.html` (default location)
2. `tmp/report.html` (alternative location)

```typescript
import { loadReport } from './test-utils';

test('my test', async ({ page }) => {
  await loadReport(page);
  // Test assertions here
});
```

## Configuration

Tests are configured in `playwright.config.ts` at the project root:

- **Browsers**: Chromium, Firefox, WebKit
- **Base URL**: `file://` protocol for local HTML
- **Timeout**: 30 seconds per test
- **Retries**: 2 on CI, 0 locally
- **Workers**: 4 parallel workers
- **Screenshots**: On failure only
- **Videos**: On first retry

## Best Practices

### Writing Tests

1. **Use Descriptive Names**: Test names should clearly describe what they validate
2. **Keep Tests Focused**: One test should validate one behavior
3. **Use Locators**: Prefer CSS selectors for stability
4. **Wait for Elements**: Use `await expect(element).toBeVisible()` before interacting
5. **Group Related Tests**: Use `test.describe()` for logical grouping

### Example Test

```typescript
import { test, expect } from '@playwright/test';
import { loadReport } from './test-utils';

test.describe('Feature Name', () => {
  test.beforeEach(async ({ page }) => {
    await loadReport(page);
  });

  test('validates specific behavior', async ({ page }) => {
    const element = page.locator('.my-selector');
    await expect(element).toBeVisible();
    await expect(element).toHaveText('Expected Text');
  });
});
```

## Debugging Failed Tests

### View Test Results

```bash
# Show HTML report
npx playwright show-report

# View screenshots of failures
open test-results/
```

### Debug Interactively

```bash
# Run with UI mode
npx playwright test --ui

# Debug specific test
npx playwright test --debug e2e/key-metrics.spec.ts:9
```

### Common Issues

**Test Timeout**
- Increase timeout in test or config
- Check if report is generated correctly
- Verify report path matches expectation

**Element Not Found**
- Check selector specificity
- Verify element exists in report
- Wait for dynamic content to load

**Visual Regression Failures**
- Review diff images in test results
- Update snapshots if change is intentional: `--update-snapshots`
- Check for environment-specific rendering differences

## CI Integration

Tests run automatically in GitHub Actions CI:

```yaml
- name: Run E2E Tests
  run: npm test
```

On CI:
- Tests run in headless mode
- 2 retries on failure
- Screenshots/videos captured on failure
- HTML report artifact uploaded

## Coverage

Current e2e coverage:
- ✅ 77 tests passing
- ✅ Accessibility (WCAG 2.1 AA)
- ✅ Cross-browser (Chromium, Firefox, WebKit)
- ✅ Mobile responsiveness
- ✅ Data integrity
- ✅ Visual regression
- ✅ Interactive elements
- ✅ Charts and visualizations

## Maintaining Tests

### When Report Changes

1. **New Metric Added**: Update count in `key-metrics.spec.ts`
2. **UI Changes**: Review and update visual snapshots
3. **New Section**: Add new test file following naming convention
4. **Chart Changes**: Update chart validation in `charts.spec.ts`

### Test Updates

Always run full test suite after report changes:

```bash
# Generate fresh report
./bin/wttj-metrics report tmp/metrics.csv

# Run e2e tests
npm test

# Update snapshots if needed
npx playwright test --update-snapshots
```

## Resources

- [Playwright Documentation](https://playwright.dev)
- [Playwright Best Practices](https://playwright.dev/docs/best-practices)
- [Accessibility Testing Guide](https://playwright.dev/docs/accessibility-testing)
- [Visual Comparisons](https://playwright.dev/docs/test-snapshots)

## Contributing

When adding new e2e tests:

1. Follow existing test structure and naming
2. Add descriptive test names
3. Update this README with new test coverage
4. Ensure tests are deterministic (no flaky tests)
5. Add to appropriate test suite or create new file
6. Document any new test utilities in `test-utils.ts`

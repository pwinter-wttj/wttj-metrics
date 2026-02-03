# Templates

This directory contains ERB (Embedded Ruby) templates used to generate the HTML reports.

## Files

### linear_report.html.erb

The main HTML template for the comprehensive metrics report. This template generates a complete, interactive HTML page with charts, tables, and visualizations.

**Sections:**

1. **Header & Navigation**
   - Report title and metadata
   - Date range and generation timestamp
   - Navigation links to sections

2. **Overview Section**
   - High-level metrics summary
   - Total issues, cycles, teams
   - Key performance indicators (KPIs)

3. **Cycle Metrics Section**
   - Cycles by Team table with:
     - Cycle name and date range
     - Scope change percentages
     - Completion rates with progress bars
     - Issue counts (planned, added, completed)
   - Scope Change vs Completion chart (scatter plot)
   - Cycles Timeline chart (bar chart)

4. **Team Comparison Section**
   - Team Metrics table with:
     - Team names
     - Median completion rates (with progress bars)
     - Median scope changes
     - Total cycles per team
   - Color-coded performance indicators

5. **Bug Tracking Section**
   - Bug Status Overview with metric cards:
     - Total bugs
     - Open bugs
  - MTTR (Median Time To Resolution)
     - Resolution rate
   - Bug Status Distribution chart (pie chart)
   - Bugs by Priority chart (bar chart)
   - Bug Flow Over Time chart (line chart)
   - Bugs by Team chart (bar chart)
   - Bug Stats by Team table (sortable) with:
     - Open bugs
     - In Progress bugs
     - Resolved bugs
     - Total bugs
     - MTTR per team
     - Resolution rate per team

**Technologies Used:**

- **HTML5**: Semantic markup
- **CSS3**: Styling with Flexbox and Grid
  - Custom CSS variables for theming
  - Responsive design with media queries
  - Print-friendly styles
- **JavaScript**: 
  - Chart.js for data visualizations
  - Table sorting functionality
  - Interactive hover effects
- **ERB**: Ruby templating for dynamic content

**Data Binding:**

The template receives data from the `ReportGenerator` through instance variables:

```ruby
# From report_generator.rb
@data = {
  overview: { ... },
  cycles: [ ... ],
  teams: { ... },
  bugs: { ... }
}

# Access in template
<% @data[:cycles].each do |cycle| %>
  <% presenter = CyclePresenter.new(cycle) %>
  <td><%= presenter.name %></td>
<% end %>
```

**Chart.js Integration:**

Charts are initialized with data formatted by presenters:

```javascript
new Chart(ctx, {
  type: 'scatter',
  data: {
    datasets: [{
      label: 'Scope Change vs Completion',
      data: <%= @chart_data[:scope_vs_completion].to_json %>
    }]
  },
  options: { ... }
});
```

**Interactive Features:**

1. **Sortable Tables**
   - Click column headers to sort ascending/descending
   - Visual indicators (⇅, ▲, ▼)
   - Smart sorting for numbers, percentages, and strings
   - Default sort by Resolution Rate (descending)

2. **Hover Effects**
   - Table rows highlight on hover
   - Chart tooltips show detailed data
   - Badge hover effects

3. **Responsive Design**
   - Desktop: Full multi-column layout
   - Tablet: Adjusted column widths
   - Mobile: Single-column stacked layout
   - Print: Optimized for paper output

**CSS Classes:**

- `.metric-card` - KPI summary cards
- `.progress` - Progress bar container
- `.progress-fill` - Progress bar fill with color coding
- `.badge` - Status and metric badges
- `.sortable` - Sortable table headers
- `.completion-high/medium/low` - Completion rate colors
- `.scope-low/medium/high` - Scope change colors

**JavaScript Functions:**

- `sortBugStatsTable(columnIndex, type)` - Sorts Bug Stats table
  - Handles numbers, strings, percentages in badges
  - Toggles between ascending and descending
  - Updates visual indicators

**Performance Optimizations:**

- Inline CSS to avoid external requests
- Chart.js loaded from CDN with fallback
- Minimal JavaScript for fast load times
- Efficient data structures for sorting

**Accessibility:**

- Semantic HTML5 elements
- ARIA labels for interactive elements
- Keyboard navigation support
- High contrast color schemes
- Screen reader friendly tables

## Template Structure

```
linear_report.html.erb
├── <head>
│   ├── <meta> tags
│   ├── <title>
│   └── <style> (inline CSS)
├── <body>
│   ├── Header
│   │   └── Report metadata
│   ├── Overview Section
│   │   └── Summary metrics
│   ├── Cycle Metrics Section
│   │   ├── Cycles by Team table
│   │   └── Cycle charts
│   ├── Team Comparison Section
│   │   └── Team metrics table
│   └── Bug Tracking Section
│       ├── Bug overview cards
│       ├── Bug charts
│       └── Bug Stats by Team table
├── <script> (Chart.js CDN)
└── <script> (inline JavaScript)
```

## Customization

### Adding New Sections

1. Add data to `@data` hash in `ReportGenerator`
2. Create a presenter for formatting
3. Add HTML section to template
4. Add CSS styles for the section
5. Add JavaScript if interactive features needed

### Modifying Charts

Charts can be customized by modifying the Chart.js configuration:

```javascript
options: {
  scales: {
    y: { beginAtZero: true },
    x: { type: 'time' }
  },
  plugins: {
    legend: { position: 'top' },
    tooltip: { mode: 'index' }
  }
}
```

### Changing Colors

Color schemes are defined in CSS variables:

```css
:root {
  --primary-color: #007bff;
  --success-color: #28a745;
  --warning-color: #ffc107;
  --danger-color: #dc3545;
}
```

## Best Practices

1. **Use Presenters**: Always format data through presenters, not in the template
2. **Keep Logic Minimal**: Templates should contain display logic only
3. **Semantic HTML**: Use appropriate HTML5 elements
4. **Inline Critical CSS**: Inline CSS for faster rendering
5. **Optimize Images**: Use SVG for icons when possible
6. **Test Responsiveness**: Test on multiple screen sizes
7. **Validate HTML**: Ensure valid HTML5 markup
8. **Accessibility**: Include ARIA labels and semantic elements

## Testing

Templates are tested through:
- E2E tests in `e2e/` directory using Playwright
- Visual regression testing
- Cross-browser compatibility testing (Chromium, Firefox, WebKit, Mobile)
- Print layout testing

Run E2E tests:
```bash
npm test
```

## Output

The template generates a single, self-contained HTML file:
- No external dependencies (except Chart.js CDN)
- Can be opened directly in any browser
- Can be printed or saved as PDF
- Can be shared via email or stored in version control

Example output location:
```
tmp/report.html
report/report.html
```

## Dependencies

- **Chart.js**: v4.4.0 - Data visualization library
- **ERB**: Ruby's built-in templating engine
- **Presenters**: For data formatting (see presenters/README.md)

## Browser Compatibility

Tested and supported on:
- Chrome/Chromium 90+
- Firefox 88+
- Safari 14+
- Edge 90+
- Mobile Chrome (Android)
- Mobile Safari (iOS)

# Helpers

This directory contains utility modules that provide common formatting and data manipulation functions used throughout the application.

## Modules

### DateHelper

Provides date manipulation and formatting utilities for working with weeks, dates, and time ranges.

**Key Methods:**
- `parse_date(date_string, format: :date)` - Safely parses a date string, returns Date object by default or string (YYYY-MM-DD) if format: :string. Returns nil on error.
- `parse_datetime(date_string)` - Safely parses a datetime string
- `monday_of_week(date)` - Returns the Monday of the week containing the given date
- `format_week_label(date)` - Formats a date as "Mon DD" (e.g., "Dec 02")
- `days_ago(days, from: Date.today)` - Returns date string for N days ago
- `days_between(start_date, end_date)` - Calculates number of days between two dates
- `hours_between(start_time, end_time)` - Calculates number of hours between two timestamps

**Usage Example:**
```ruby
include WttjMetrics::Helpers::DateHelper

# Get week start
monday = monday_of_week(Date.today)

# Calculate duration
days = days_between('2024-01-01', '2024-01-10') # => 9
hours = hours_between(start_time, end_time)
```

### FormattingHelper

Provides consistent formatting utilities for numbers, percentages, and metric names.

**Key Methods:**
- `format_percentage(value, total)` - Calculates and formats a percentage (returns integer)
- `format_with_unit(value, unit)` - Appends unit to value
- `humanize_metric_name(name)` - Converts snake_case to human readable string
- `format_count_display(completed, total)` - Formats as "X/Y"
- `format_points_display(points)` - Formats as "X pts"

**Usage Example:**
```ruby
include WttjMetrics::Helpers::FormattingHelper

# Format percentages
pct = format_percentage(25, 100)  # => 25

# Humanize names
name = humanize_metric_name('avg_cycle_time') # => "Median cycle time"
```

### Linear::IssueHelper

Provides utilities for extracting data from Linear issues.

**Key Methods:**
- `issue_is_bug?(issue)` - Determines if an issue is a bug based on labels
- `extract_labels(issue)` - Returns array of label names
- `extract_team_name(issue)` - Extracts team name
- `extract_assignee_name(issue)` - Extracts assignee name
- `extract_priority_label(issue)` - Extracts priority label
- `issue_completed?(issue)` - Checks if issue has completedAt date
- `issue_started?(issue)` - Checks if issue has startedAt date

**Usage Example:**
```ruby
include WttjMetrics::Helpers::Linear::IssueHelper

if issue_is_bug?(issue)
  team = extract_team_name(issue)
  priority = extract_priority_label(issue)
end
```

### LoggerMixin

Provides a shared logger configuration for CLI classes.

**Key Methods:**
- `logger` - Returns a configured Logger instance
- `create_logger` - Creates a new Logger with custom formatter

**Usage Example:**
```ruby
include WttjMetrics::Helpers::LoggerMixin

def run
  logger.info "Starting process..."
end
```

## Design Principles

1. **Single Responsibility**: Each helper focuses on a specific domain
2. **Reusability**: Methods are designed to be used across multiple presenters and calculators
3. **Consistency**: Provides standardized formatting throughout the application
4. **Testability**: All helpers are fully unit tested

## Dependencies

- `date` - Ruby standard library for date manipulation
- `logger` - Ruby standard library for logging

## Testing

All helpers have comprehensive test coverage in `spec/wttj_metrics/helpers/`:
- `date_helper_spec.rb` - Tests for date calculations and formatting
- `formatting_helper_spec.rb` - Tests for number and percentage formatting
- `linear/issue_helper_spec.rb` - Tests for issue filtering and status checking

Run tests with:
```bash
bundle exec rspec spec/wttj_metrics/helpers/
```

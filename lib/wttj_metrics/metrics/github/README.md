# GitHub Metrics

This directory contains calculators for analyzing GitHub pull request data. These calculators process raw PR data to generate insights about velocity, quality, collaboration, and activity.

## Calculators

### PrVelocityCalculator
Calculates velocity-related metrics for Pull Requests.

**Metrics:**
- **Avg Time to Merge**: Median duration from PR creation to merge.
- **Avg Time to First Review**: Median duration from PR creation to the first review comment.
- **Avg Reviews per PR**: Median number of reviews received per PR.
- **Avg Comments per PR**: Median number of comments (general comments) per PR.

### QualityCalculator
Analyzes code quality indicators.

**Metrics:**
- **Merge Rate**: Percentage of PRs that are merged.
- **Unreviewed PR Rate**: Percentage of PRs merged without review.
- **CI Success Rate**: Percentage of successful CI runs.
- **Hotfix Rate**: Percentage of PRs identified as hotfixes.
- **Time to Green**: Median time for CI to pass.

### PrSizeCalculator
Analyzes the size of Pull Requests.

**Metrics:**
- **Avg Additions**: Median lines added per PR.
- **Avg Deletions**: Median lines deleted per PR.
- **Avg Changed Files**: Median files changed per PR.
- **Avg Commits**: Median commits per PR.

### RepositoryActivityCalculator
Analyzes activity levels across different repositories.

**Metrics:**
- **Top 10 Repositories**: Lists the 10 most active repositories based on PR count.
- **Daily Activity**: Breakdown of PRs created per repository per day.

### TimeseriesCalculator
Generates comprehensive daily time-series data for PR lifecycle events, code quality, and release activity.

**Metrics:**
- **PR Activity**: Created, Merged, Closed, Open counts, and Merge Time.
- **Review Efficiency**: Reviews/Comments per PR, Rework Cycles, Time to First Review/Approval.
- **Code Volume**: Additions and Deletions per PR.
- **CI Performance**: Success Rate and Time to Green.
- **Release Activity**: Release counts and Hotfix rates.

### CollaborationCalculator
Analyzes collaboration patterns and review efficiency.

**Metrics:**
- **Avg Reviews per PR**: Average number of reviews received per PR.
- **Avg Comments per PR**: Average number of comments per PR.
- **Avg Rework Cycles**: Average number of "changes requested" reviews per PR.
- **Unreviewed PR Rate**: Percentage of PRs merged without any review.

### CommitActivityCalculator
Calculates commit activity patterns for heatmap visualization.

**Metrics:**
- **Commit Activity**: Aggregated commit counts by day of week and hour of day.

### ContributorActivityCalculator
Tracks individual contributor activity over time.

**Metrics:**
- **Contributor Activity**: Daily count of PRs created by each contributor.

See [Timeseries Metrics](timeseries/README.md) for detailed component documentation.

## Usage

Calculators are typically instantiated with a collection of PR data and then called to perform the calculation.

```ruby
# Example usage
calculator = WttjMetrics::Metrics::Github::PrVelocityCalculator.new(pull_requests)
metrics = calculator.calculate

puts "Average Time to Merge: #{metrics[:avg_time_to_merge]} hours"
```

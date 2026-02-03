# frozen_string_literal: true

require 'json'

module WttjMetrics
  module Metrics
    module Linear
      # Calculates distribution metrics (status, priority, type, size, assignee)
      class DistributionCalculator < Base
        include Helpers::Linear::IssueHelper
        include Helpers::StatisticsHelper

        def calculate
          {
            status: status_distribution,
            priority: priority_distribution,
            type: type_distribution,
            type_breakdown: type_breakdown,
            size: size_distribution,
            assignee: assignee_distribution
          }
        end

        def to_rows
          calculate.flat_map do |category, distribution|
            build_distribution_rows(category, distribution)
          end
        end

        # Also expose backlog age as an issue characteristic
        def backlog_metrics
          { median_backlog_age_days: median_backlog_age }
        end

        def backlog_rows
          [[today.to_s, 'issues', 'median_backlog_age_days', median_backlog_age]]
        end

        private

        def build_distribution_rows(category, distribution)
          distribution.map do |key, value|
            [today.to_s, category.to_s, key.to_s, value]
          end
        end

        def status_distribution
          count_by_attribute { |issue| issue.dig('state', 'name') || 'Unknown' }
        end

        def priority_distribution
          count_by_attribute { |issue| extract_priority_label(issue) }
        end

        def count_by_attribute(collection = issues, &)
          collection.each_with_object(Hash.new(0)) do |issue, dist|
            dist[yield(issue)] += 1
          end
        end

        def type_distribution
          default_types = ['Feature', 'Bug', 'Improvement', 'Tech Debt', 'Task', 'Documentation', 'Other']
          distribution = default_types.to_h { |type| [type, 0] }

          issues.each do |issue|
            issue_type = classify_issue_type(issue)
            distribution[issue_type] += 1
          end

          distribution
        end

        def type_breakdown
          breakdown = Hash.new { |h, k| h[k] = Hash.new(0) }

          issues.each do |issue|
            populate_type_breakdown(breakdown, issue)
          end

          breakdown.transform_values(&:to_json)
        end

        def populate_type_breakdown(breakdown, issue)
          issue_type = classify_issue_type(issue)
          labels = extract_labels(issue)

          if labels.empty?
            breakdown[issue_type]['(No Label)'] += 1
          else
            labels.each { |label| breakdown[issue_type][label] += 1 }
          end
        end

        def classify_issue_type(issue)
          labels = extract_labels(issue)
          title = extract_title(issue)

          classify_by_labels(labels) || classify_by_title(title) || 'Other'
        end

        def extract_title(issue)
          (issue['title'] || '').downcase
        end

        def classify_by_labels(labels)
          return 'Bug' if bug_pattern?(labels)
          return 'Feature' if feature_pattern?(labels)
          return 'Improvement' if improvement_pattern?(labels)
          return 'Tech Debt' if tech_debt_pattern?(labels)
          return 'Task' if task_pattern?(labels)
          return 'Documentation' if documentation_pattern?(labels)

          nil
        end

        def classify_by_title(title)
          return 'Bug' if title_indicates_bug?(title)
          return 'Feature' if title_indicates_feature?(title)
          return 'Improvement' if title_indicates_improvement?(title)
          return 'Tech Debt' if title_indicates_tech_debt?(title)
          return 'Task' if title_indicates_task?(title)
          return 'Documentation' if title_indicates_documentation?(title)

          nil
        end

        def bug_pattern?(labels)
          match_any_label?(labels, /\b(bug|bugs|hotfix|fix)\b/)
        end

        def feature_pattern?(labels)
          match_any_label?(labels, /\b(feature|enhancement|ai-feature)\b/)
        end

        def improvement_pattern?(labels)
          match_any_label?(labels, /\bimprovement/)
        end

        def tech_debt_pattern?(labels)
          labels.any? { |label| tech_debt_label?(label) }
        end

        def tech_debt_label?(label)
          label =~ /\b(debt|refactor|migration|migrated|upgrade|component upgrade)\b/ &&
            !label.include?('front-end') &&
            !label.include?('back-end') &&
            label != 'tech'
        end

        def task_pattern?(labels)
          match_any_label?(labels, /\b(task|chore|cooldown|testing|manual testing)\b/)
        end

        def documentation_pattern?(labels)
          match_any_label?(labels, /\b(doc|documentation|writing|content fix)\b/)
        end

        def match_any_label?(labels, pattern)
          labels.any? { |label| label =~ pattern }
        end

        # Title-based classification methods (fallback for unlabeled issues)
        def title_indicates_bug?(title)
          title =~ /\[bug\]|^bug[:\s]|fix\s+(bug|issue|error)|broken|crash|not working/i
        end

        def title_indicates_feature?(title)
          # Avoid matching simple "add" for config/docs; look for "add new X" or "create X"
          title =~ /\badd\s+(new|support|ability|feature|functionality)|^create\s+\w+\s+(for|to)|
                     implement\s+new|introduce\s+/xi
        end

        def title_indicates_improvement?(title)
          title =~ /\bimprove|enhance|optimize|better|refine|polish|cleanup/i
        end

        def title_indicates_tech_debt?(title)
          title =~ /\brefactor|upgrade|migrate|migration|update\s+\w+\s+to\s+|modernize|consolidate/i
        end

        def title_indicates_task?(title)
          # Generic task indicators or exploratory work
          title =~ /^(explore|investigate|research|review|analyze|test|verify|validate|check)\b/i
        end

        def title_indicates_documentation?(title)
          title =~ /\bdocument|docs|readme|guide|tutorial|example|write\s+doc/i
        end

        def size_distribution
          size_categories = ['No estimate', 'Small (1-2)', 'Medium (3-5)', 'Large (8+)']
          distribution = size_categories.to_h { |category| [category, 0] }

          issues.each do |issue|
            size_category = classify_size(issue['estimate'])
            distribution[size_category] += 1
          end

          distribution
        end

        def classify_size(estimate)
          case estimate
          when nil, 0 then 'No estimate'
          when 1, 2 then 'Small (1-2)'
          when 3, 4, 5 then 'Medium (3-5)'
          else 'Large (8+)'
          end
        end

        def assignee_distribution
          count_by_attribute(in_progress_issues) { |issue| extract_assignee_name(issue) }
        end

        def in_progress_issues
          filter_issues_by_state('started')
        end

        def filter_issues_by_state(state_type)
          issues.select { |issue| issue.dig('state', 'type') == state_type }
        end

        def median_backlog_age
          backlog_issues = filter_issues_by_state('backlog')
          return 0 if backlog_issues.empty?

          ages = backlog_issues.map do |issue|
            created = parse_datetime(issue['createdAt'])
            (today.to_datetime - created).to_f
          end

          safe_median(ages, precision: 2)
        end
      end
    end
  end
end

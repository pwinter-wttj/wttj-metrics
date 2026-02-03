# frozen_string_literal: true

module WttjMetrics
  module Presenters
    # Presenter for bug metrics
    class BugMetricPresenter < BasePresenter
      TOOLTIPS = {
        'total_bugs' => 'Total number of issues labeled as bugs.',
        'open_bugs' => 'Bugs that are not yet completed.',
        'closed_bugs' => 'Bugs that have been completed.',
        'bugs_created_last_30d' => 'New bugs created in the last 30 days.',
        'bugs_closed_last_30d' => 'Bugs resolved in the last 30 days.',
        'median_bug_resolution_days' => 'Median time to resolve a bug.',
        'bug_ratio' => 'Percentage of issues that are bugs.'
      }.freeze

      def label
        case name
        when 'bug_ratio' then 'Issues are bugs'
        else
          name.tr('_', ' ')
              .gsub('bugs ', '')
              .gsub('bug ', '')
              .gsub('median ', 'Median ')
              .strip
              .capitalize
        end
      end

      def tooltip
        TOOLTIPS[name] || ''
      end

      def unit
        case name
        when 'median_bug_resolution_days' then ' days'
        when 'bug_ratio' then '%'
        else ''
        end
      end

      def value
        # Bug ratio keeps decimal, others are integers
        name.include?('ratio') ? raw_value.round(1) : raw_value.to_i
      end
    end
  end
end

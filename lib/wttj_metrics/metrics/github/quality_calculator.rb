# frozen_string_literal: true

require 'date'
require 'time'

module WttjMetrics
  module Metrics
    module Github
      class QualityCalculator
        CATEGORY = 'github'
        METRICS = {
          ci_success_rate: 'ci_success_rate',
          deploy_frequency_weekly: 'deploy_frequency_weekly',
          deploy_frequency_daily: 'deploy_frequency_daily',
          hotfix_rate: 'hotfix_rate',
          time_to_green_hours: 'time_to_green_hours'
        }.freeze

        def initialize(pull_requests, releases)
          @pull_requests = pull_requests
          @releases = releases
        end

        def calculate
          {
            ci_success_rate: calculate_ci_success_rate,
            deploy_frequency_weekly: calculate_deploy_frequency_weekly,
            deploy_frequency_daily: calculate_deploy_frequency_daily,
            hotfix_rate: calculate_hotfix_rate,
            time_to_green_hours: calculate_time_to_green
          }
        end

        def to_rows(category = CATEGORY)
          date = Date.today.to_s
          calculate.map do |key, value|
            [date, category, METRICS[key], value]
          end
        end

        private

        def merged_prs
          @merged_prs ||= @pull_requests.select { |pr| pr[:state] == 'MERGED' }
        end

        def sorted_releases
          @sorted_releases ||= @releases.sort_by { |r| r['created_at'] }
        end

        def calculate_ci_success_rate
          return 0.0 if merged_prs.empty?

          success_count = merged_prs.count { |pr| ci_success?(pr) }
          (success_count.to_f / merged_prs.size * 100).round(2)
        end

        def ci_success?(pull_request)
          commit = last_commit(pull_request)
          return false unless commit

          commit.dig(:statusCheckRollup, :state) == 'SUCCESS'
        end

        def calculate_deploy_frequency_weekly
          return 0.0 if @releases.empty?

          weeks = [release_span_days / 7.0, 1.0].max
          (@releases.size / weeks).round(2)
        end

        def calculate_deploy_frequency_daily
          return 0.0 if @releases.empty?

          days = [release_span_days, 1.0].max
          (@releases.size.to_f / days).round(2)
        end

        def release_span_days
          first_date = Date.parse(sorted_releases.first['created_at'].to_s)
          (Date.today - first_date).to_i
        end

        def calculate_hotfix_rate
          return 0.0 if @releases.empty?

          hotfix_count = @releases.count { |r| hotfix?(r) }
          (hotfix_count.to_f / @releases.size * 100).round(2)
        end

        def hotfix?(release)
          name = release['name'] || ''
          tag = release['tag_name'] || ''
          name.downcase.include?('hotfix') || tag.downcase.include?('hotfix')
        end

        def calculate_time_to_green
          return 0.0 if merged_prs.empty?

          times = merged_prs.filter_map { |pr| time_to_green_for_pr(pr) }
          return 0.0 if times.empty?

          median(times).round(2)
        end

        def median(values)
          sorted = values.sort
          mid = sorted.length / 2
          return sorted[mid] if sorted.length.odd?

          (sorted[mid - 1] + sorted[mid]) / 2.0
        end

        def time_to_green_for_pr(pull_request)
          commit = last_commit(pull_request)
          return nil unless commit && commit[:committedDate]

          suite = latest_successful_suite(commit)
          return nil unless suite

          (Time.parse(suite[:updatedAt]) - Time.parse(commit[:committedDate])) / 3600.0
        end

        def last_commit(pull_request)
          pull_request.dig(:lastCommit, :nodes)&.last&.dig(:commit)
        end

        def latest_successful_suite(commit)
          suites = commit.dig(:checkSuites, :nodes)
          return nil unless suites

          suites.select { |cs| cs[:conclusion] == 'SUCCESS' }
                .max_by { |cs| cs[:updatedAt] }
        end
      end
    end
  end
end

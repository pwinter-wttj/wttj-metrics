# frozen_string_literal: true

require 'spec_helper'
require 'wttj_metrics/metrics/github/timeseries_calculator'

RSpec.describe WttjMetrics::Metrics::Github::TimeseriesCalculator do
  subject(:calculator) { described_class.new(pull_requests) }

  let(:pull_requests) do
    [
      {
        createdAt: '2025-01-01T10:00:00Z',
        mergedAt: '2025-01-01T12:00:00Z',
        state: 'MERGED',
        reviews: {
          totalCount: 2,
          nodes: [
            { createdAt: '2025-01-01T10:30:00Z' }, # 30 mins
            { createdAt: '2025-01-01T11:00:00Z' }
          ]
        },
        comments: { totalCount: 3 },
        additions: 100,
        deletions: 20,
        lastCommit: {
          nodes: [
            {
              commit: {
                committedDate: '2025-01-01T11:30:00Z',
                checkSuites: {
                  nodes: [
                    { conclusion: 'SUCCESS', updatedAt: '2025-01-01T11:45:00Z' }
                  ]
                }
              }
            }
          ]
        }
      },
      {
        createdAt: '2025-01-01T14:00:00Z',
        mergedAt: '2025-01-01T15:00:00Z',
        state: 'MERGED',
        reviews: {
          totalCount: 1,
          nodes: [
            { createdAt: '2025-01-01T14:15:00Z' } # 15 mins
          ]
        },
        comments: { totalCount: 1 },
        additions: 50,
        deletions: 10,
        lastCommit: {
          nodes: [
            {
              commit: {
                committedDate: '2025-01-01T14:30:00Z',
                checkSuites: {
                  nodes: [
                    { conclusion: 'SUCCESS', updatedAt: '2025-01-01T14:45:00Z' }
                  ]
                }
              }
            }
          ]
        }
      },
      {
        createdAt: '2025-01-02T10:00:00Z',
        state: 'OPEN',
        reviews: { totalCount: 0, nodes: [] },
        comments: { totalCount: 0 },
        additions: 0,
        deletions: 0
      }
    ]
  end

  describe '#to_rows' do
    it 'calculates daily stats including median_time_to_merge_hours, reviews and comments' do
      rows = calculator.to_rows

      # 2025-01-01
      # PR 1: 2 hours, 2 reviews, 3 comments, 100 additions, 20 deletions, 0.5h to first review
      # PR 2: 1 hour, 1 review, 1 comment, 50 additions, 10 deletions, 0.25h to first review
      # Avg: 1.5 hours, 1.5 reviews, 2.0 comments, 75.0 additions, 15.0 deletions, 0.38h to first review

      day1_rows = rows.select { |r| r[0] == '2025-01-01' }
      median_time_row = day1_rows.find { |r| r[2] == 'median_time_to_merge_hours' }
      median_reviews_row = day1_rows.find { |r| r[2] == 'median_reviews_per_pr' }
      median_comments_row = day1_rows.find { |r| r[2] == 'median_comments_per_pr' }
      median_additions_row = day1_rows.find { |r| r[2] == 'median_additions_per_pr' }
      median_deletions_row = day1_rows.find { |r| r[2] == 'median_deletions_per_pr' }
      median_time_first_review_row = day1_rows.find { |r| r[2] == 'median_time_to_first_review_days' }
      median_time_to_green_row = day1_rows.find { |r| r[2] == 'median_time_to_green_hours' }

      expect(median_time_row).not_to be_nil
      expect(median_time_row[3]).to eq(1.5)
      expect(median_reviews_row[3]).to eq(1.5)
      expect(median_comments_row[3]).to eq(2.0)
      expect(median_additions_row[3]).to eq(75.0)
      expect(median_deletions_row[3]).to eq(15.0)
      expect(median_time_first_review_row[3]).to eq(0.02)
      expect(median_time_to_green_row[3]).to eq(0.25)

      # 2025-01-02
      day2_rows = rows.select { |r| r[0] == '2025-01-02' }
      median_time_row2 = day2_rows.find { |r| r[2] == 'median_time_to_merge_hours' }

      expect(median_time_row2).not_to be_nil
      expect(median_time_row2[3]).to eq(0.0)
    end
  end
end

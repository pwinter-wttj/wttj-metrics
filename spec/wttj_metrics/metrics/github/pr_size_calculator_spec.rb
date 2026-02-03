# frozen_string_literal: true

require 'spec_helper'
require 'wttj_metrics/metrics/github/pr_size_calculator'

RSpec.describe WttjMetrics::Metrics::Github::PrSizeCalculator do
  subject(:calculator) { described_class.new(pull_requests) }

  let(:pull_requests) do
    [
      {
        additions: 100,
        deletions: 50,
        changedFiles: 5,
        commits: { totalCount: 3 }
      },
      {
        additions: 200,
        deletions: 10,
        changedFiles: 2,
        commits: { totalCount: 1 }
      }
    ]
  end

  describe '#to_rows' do
    it 'calculates median size metrics' do
      rows = calculator.to_rows

      # Avg Additions: (100 + 200) / 2 = 150
      # Avg Deletions: (50 + 10) / 2 = 30
      # Avg Files: (5 + 2) / 2 = 3.5
      # Avg Commits: (3 + 1) / 2 = 2

      additions_row = rows.find { |r| r[2] == 'median_additions_per_pr' }
      deletions_row = rows.find { |r| r[2] == 'median_deletions_per_pr' }
      files_row = rows.find { |r| r[2] == 'median_changed_files_per_pr' }
      commits_row = rows.find { |r| r[2] == 'median_commits_per_pr' }

      expect(additions_row[3]).to eq(150.0)
      expect(deletions_row[3]).to eq(30.0)
      expect(files_row[3]).to eq(3.5)
      expect(commits_row[3]).to eq(2.0)
    end
  end
end

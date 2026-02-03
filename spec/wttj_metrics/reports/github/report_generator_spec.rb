# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WttjMetrics::Reports::Github::ReportGenerator do
  let(:csv_path) { 'spec/fixtures/github_metrics.csv' }
  let(:metrics_data) do
    [
      { date: yesterday, metric: 'median_time_to_merge_days', value: 2.5 },
      { date: today, metric: 'median_time_to_merge_days', value: 2.0 },
      { date: yesterday, metric: 'total_merged_prs', value: 10 },
      { date: today, metric: 'total_merged_prs', value: 15 },
      { date: yesterday, metric: 'median_reviews_per_pr', value: 1.5 },
      { date: today, metric: 'median_reviews_per_pr', value: 1.8 },
      { date: yesterday, metric: 'median_comments_per_pr', value: 3.0 },
      { date: today, metric: 'median_comments_per_pr', value: 3.5 },
      { date: today, metric: 'median_additions_per_pr', value: 100 },
      { date: today, metric: 'median_deletions_per_pr', value: 50 },
      { date: today, metric: 'median_changed_files_per_pr', value: 5 },
      { date: today, metric: 'median_commits_per_pr', value: 2 },
      { date: today, metric: 'median_time_to_first_review_days', value: 0.5 }
    ]
  end
  let(:generator) { described_class.new(csv_path) }
  let(:today) { Date.today.to_s }
  let(:yesterday) { (Date.today - 1).to_s }
  let(:parser) { instance_double(WttjMetrics::Data::CsvParser) }

  before do
    allow(Date).to receive(:today).and_return(Date.parse('2025-12-09'))

    # Mock CsvParser
    allow(WttjMetrics::Data::CsvParser).to receive(:new).with(csv_path).and_return(parser)

    allow(parser).to receive_messages(data: [], metrics_by_category: { 'github' => metrics_data })
  end

  describe '#metrics' do
    it 'returns latest metrics' do
      expect(generator.metrics).to eq({
                                        median_time_to_merge: 2.0,
                                        total_merged: 15,
                                        median_reviews: 1.8,
                                        median_comments: 3.5,
                                        median_additions: 100,
                                        median_deletions: 50,
                                        median_changed_files: 5,
                                        median_commits: 2,
                                        median_time_to_first_review: 0.5,
                                        merge_rate: 0,
                                        median_time_to_approval: 0,
                                        median_rework_cycles: 0,
                                        unreviewed_pr_rate: 0,
                                        ci_success_rate: 0,
                                        deploy_frequency: 0,
                                        deploy_frequency_daily: 0.0,
                                        hotfix_rate: 0,
                                        time_to_green: 0
                                      })
    end

    context 'with daily deploy frequency fallback' do
      let(:metrics_data) do
        [
          { date: today, metric: 'deploy_frequency_weekly', value: 14.0 }
        ]
      end

      it 'calculates daily deploy frequency from weekly' do
        # 14 / 7 = 2.0
        expect(generator.metrics[:deploy_frequency_daily]).to eq(2.0)
      end
    end

    context 'with explicit daily deploy frequency' do
      let(:metrics_data) do
        [
          { date: today, metric: 'deploy_frequency_daily', value: 3.5 }
        ]
      end

      it 'returns the explicit value' do
        expect(generator.metrics[:deploy_frequency_daily]).to eq(3.5)
      end
    end
  end

  describe '#top_repositories' do
    let(:metrics_data) do
      [
        { date: today, metric: 'repo-a', value: 10 },
        { date: today, metric: 'repo-b', value: 5 },
        { date: today, metric: 'repo-c', value: 20 }
      ]
    end

    before do
      allow(parser).to receive_messages(metrics_by_category: { 'github_repo_activity' => metrics_data })
    end

    it 'returns top 10 repositories sorted by value' do
      top = generator.send(:top_repositories)
      expect(top.size).to eq(3)
      expect(top.first[:metric]).to eq('repo-c')
      expect(top.last[:metric]).to eq('repo-b')
    end
  end

  describe '#top_contributors' do
    let(:metrics_data) do
      [
        { date: today, metric: 'user-a', value: 100 }
      ]
    end

    before do
      allow(parser).to receive_messages(metrics_by_category: { 'github_contributor_activity' => metrics_data })
    end

    it 'returns top contributors' do
      top = generator.send(:top_contributors)
      expect(top.first[:metric]).to eq('user-a')
    end
  end

  describe '#history' do
    it 'returns history for each metric' do
      history = generator.history

      expect(history[:median_time_to_merge]).to eq([
                                                  { date: yesterday, value: 2.5 },
                                                  { date: today, value: 2.0 }
                                                ])

      expect(history[:total_merged]).to eq([
                                             { date: yesterday, value: 10 },
                                             { date: today, value: 15 }
                                           ])
    end
  end

  describe '#generate_html' do
    let(:output_path) { 'tmp/report.html' }

    before do
      allow(File).to receive(:write)
      allow(File).to receive_messages(read: 'Template content', exist?: true)
    end

    it 'writes HTML report' do
      generator.generate_html(output_path)
      expect(File).to have_received(:write).with(output_path, anything)
    end
  end

  describe '#weekly_breakdown' do
    before do
      daily_data = [
        { date: '2025-12-01', metric: 'merged', value: 5 },
        { date: '2025-12-01', metric: 'closed', value: 2 },
        { date: '2025-12-01', metric: 'open', value: 10 },
        { date: '2025-12-01', metric: 'created', value: 10 },
        { date: '2025-12-01', metric: 'median_time_to_merge_hours', value: 10.0 },
        { date: '2025-12-02', metric: 'merged', value: 5 },
        { date: '2025-12-02', metric: 'closed', value: 3 },
        { date: '2025-12-02', metric: 'open', value: 12 },
        { date: '2025-12-02', metric: 'created', value: 10 },
        { date: '2025-12-02', metric: 'median_time_to_merge_hours', value: 20.0 },
        { date: '2025-12-08', metric: 'merged', value: 8 },
        { date: '2025-12-08', metric: 'closed', value: 4 },
        { date: '2025-12-08', metric: 'open', value: 15 },
        { date: '2025-12-08', metric: 'created', value: 20 },
        { date: '2025-12-08', metric: 'median_time_to_merge_hours', value: 5.0 }
      ]

      parser = instance_double(WttjMetrics::Data::CsvParser)
      allow(WttjMetrics::Data::CsvParser).to receive(:new).with(csv_path).and_return(parser)
      allow(parser).to receive_messages(data: [], metrics_by_category: { 'github' => [], 'github_daily' => daily_data })
    end

    it 'aggregates metrics by week' do
      breakdown = generator.weekly_breakdown

      expect(breakdown[:labels]).to include('2025-12-01', '2025-12-08')
      expect(breakdown[:datasets][:merged]).to eq([10, 8])
      expect(breakdown[:datasets][:open]).to eq([12, 15])
      expect(breakdown[:datasets][:median_time_to_merge]).to eq([10.0, 5.0])
    end
  end

  describe '#team_metrics' do
    let(:team_data) do
      [
        { date: '2025-01-01', metric: 'total_merged_prs', value: 10 },
        { date: '2025-01-02', metric: 'total_merged_prs', value: 5 }
      ]
    end
    let(:team_daily_data) do
      [
        { date: '2025-01-01', metric: 'merged', value: 2 },
        { date: '2025-01-02', metric: 'merged', value: 3 }
      ]
    end

    before do
      parser = instance_double(WttjMetrics::Data::CsvParser)
      allow(WttjMetrics::Data::CsvParser).to receive(:new).with(csv_path).and_return(parser)
      allow(parser).to receive_messages(
        data: [],
        metrics_by_category: {
          'github' => [],
          'github_daily' => [],
          'github:TeamA' => team_data,
          'github:TeamA_daily' => team_daily_data
        }
      )

      team_service = instance_double(WttjMetrics::Reports::Github::TeamService)
      allow(WttjMetrics::Reports::Github::TeamService).to receive(:new).and_return(team_service)
      allow(team_service).to receive(:resolve_teams).and_return(['TeamA'])
    end

    it 'calculates metrics for teams' do
      metrics = generator.team_metrics

      expect(metrics['TeamA']).not_to be_nil
      expect(metrics['TeamA'][:metrics][:total_merged]).to eq(5) # Latest value
      expect(metrics['TeamA'][:history][:total_merged].size).to eq(2)
      expect(metrics['TeamA'][:daily_breakdown][:datasets][:merged]).to include(2, 3)
    end

    context 'when no team metrics exist in the CSV but a teams config is provided' do
      subject(:configured_generator) { described_class.new(csv_path, teams_config: teams_config) }

      let(:teams_config) { instance_double(WttjMetrics::Values::TeamConfiguration, defined_teams: ['ATS']) }

      before do
        parser = instance_double(WttjMetrics::Data::CsvParser)
        allow(WttjMetrics::Data::CsvParser).to receive(:new).with(csv_path).and_return(parser)
        allow(parser).to receive_messages(data: [], metrics_by_category: { 'github' => [], 'github_daily' => [] })

        team_service = instance_double(WttjMetrics::Reports::Github::TeamService, resolve_teams: [])
        allow(WttjMetrics::Reports::Github::TeamService).to receive(:new).and_return(team_service)
      end

      it 'returns an empty hash and exposes a warning' do
        # Exercise
        metrics = configured_generator.team_metrics

        # Verify
        aggregate_failures do
          expect(metrics).to eq({})
          expect(configured_generator.team_metrics_warning).to match(/No GitHub team metrics found/i)
        end
      end
    end
  end

  describe '#generate_excel' do
    let(:repo_activity) do
      [
        { date: '2025-01-01', metric: 'repo1', value: 10 },
        { date: '2025-01-02', metric: 'repo1', value: 5 },
        { date: '2025-01-01', metric: 'repo2', value: 20 },
        { date: '2024-01-01', metric: 'repo1', value: 100 } # Should be excluded
      ]
    end
    let(:contributor_activity) do
      [
        { date: '2025-01-01', metric: 'user1', value: 5 },
        { date: '2025-01-02', metric: 'user1', value: 5 },
        { date: '2025-01-01', metric: 'user2', value: 2 }
      ]
    end

    before do
      allow(Date).to receive(:today).and_return(Date.parse('2025-01-10'))
      parser = instance_double(WttjMetrics::Data::CsvParser)
      allow(WttjMetrics::Data::CsvParser).to receive(:new).with(csv_path).and_return(parser)
      allow(parser).to receive_messages(
        data: [],
        metrics_by_category: {
          'github' => [],
          'github_daily' => [],
          'github_repo_activity' => repo_activity,
          'github_contributor_activity' => contributor_activity
        }
      )
      allow(WttjMetrics::Reports::Github::ExcelReportBuilder)
        .to receive(:new).and_return(
          instance_double(WttjMetrics::Reports::Github::ExcelReportBuilder, build: nil)
        )
    end

    it 'passes top repositories and contributors to Excel builder' do
      generator.generate_excel('output.xlsx')

      expect(WttjMetrics::Reports::Github::ExcelReportBuilder).to have_received(:new) do |data|
        expect(data[:top_repositories]).to include(
          { metric: 'repo1', value: 15, date: '2025-01-10' },
          { metric: 'repo2', value: 20, date: '2025-01-10' }
        )

        expect(data[:top_contributors]).to include(
          { metric: 'user1', value: 10, date: '2025-01-10' },
          { metric: 'user2', value: 2, date: '2025-01-10' }
        )
      end
    end
  end

  describe '#template_binding' do
    it 'returns a binding' do
      expect(generator.template_binding).to be_a(Binding)
    end
  end
end

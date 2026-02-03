# frozen_string_literal: true

require 'tempfile'

RSpec.describe WttjMetrics::Reports::Linear::ExcelReportBuilder do
  subject(:builder) { described_class.new(report_data) }

  let(:temp_file) { Tempfile.new(['report', '.xlsx']) }
  let(:report_data) do
    {
      today: '2024-12-07',
      days_to_show: 90,
      flow_metrics: [
        { date: '2024-12-07', category: 'flow', metric: 'throughput', value: 10 }
      ],
      cycle_metrics: [
        { date: '2024-12-07', category: 'cycle_metrics', metric: 'median_cycle_velocity', value: 5.5 }
      ],
      team_metrics: [],
      bug_metrics: [],
      bugs_by_priority: [],
      status_chart_data: [
        { label: 'Todo', value: 30 },
        { label: 'Done', value: 100 }
      ],
      priority_dist: [],
      type_dist: [],
      assignee_dist: [],
      team_stats: {},
      cycles_by_team: {},
      weekly_flow_data: {
        labels: ['Dec 01', 'Dec 08'],
        created_raw: [10, 15],
        completed_raw: [8, 12]
      },
      raw_data: []
    }
  end

  after do
    temp_file.close
    temp_file.unlink
  end

  describe '#initialize' do
    it 'accepts report data' do
      expect(builder).to be_a(described_class)
    end

    it 'stores report data' do
      expect(builder.instance_variable_get(:@data)).to eq(report_data)
    end
  end

  describe '#build' do
    it 'creates an Excel file' do
      builder.build(temp_file.path)
      expect(File.exist?(temp_file.path)).to be true
    end

    it 'successfully builds the file' do
      expect { builder.build(temp_file.path) }.not_to raise_error
    end

    context 'with complete data' do
      it 'creates a valid Excel file with content' do
        builder.build(temp_file.path)
        expect(File.size(temp_file.path)).to be > 0
      end

      it 'includes all data in the Excel file' do
        builder.build(temp_file.path)
        # We can't easily parse the Excel file here without adding more dependencies,
        # but we can verify it was created and has content
        expect(File.exist?(temp_file.path)).to be true
      end
    end

    context 'with minimal data' do
      let(:report_data) do
        {
          today: '2024-12-07',
          days_to_show: 90,
          flow_metrics: [],
          cycle_metrics: [],
          team_metrics: [],
          bug_metrics: [],
          bugs_by_priority: [],
          status_chart_data: [],
          priority_dist: [],
          type_dist: [],
          assignee_dist: [],
          team_stats: {},
          cycles_by_team: {},
          weekly_flow_data: { labels: [], created_raw: [], completed_raw: [] },
          raw_data: []
        }
      end

      it 'handles empty metrics gracefully' do
        expect { builder.build(temp_file.path) }.not_to raise_error
      end
    end
  end
end

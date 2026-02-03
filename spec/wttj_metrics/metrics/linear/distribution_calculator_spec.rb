# frozen_string_literal: true

RSpec.describe WttjMetrics::Metrics::Linear::DistributionCalculator do
  subject(:calculator) { described_class.new(issues, today: today) }

  # Setup
  let(:today) { Date.new(2024, 12, 5) }
  let(:issues) { [] }

  describe '#calculate' do
    subject(:result) { calculator.calculate }

    context 'with various issues' do
      # Setup
      let(:issues) do
        [
          {
            'state' => { 'name' => 'In Progress', 'type' => 'started' },
            'priorityLabel' => 'High',
            'estimate' => 3,
            'labels' => { 'nodes' => [{ 'name' => 'bug' }] },
            'assignee' => { 'name' => 'Alice' }
          },
          {
            'state' => { 'name' => 'Backlog', 'type' => 'backlog' },
            'priorityLabel' => 'Medium',
            'estimate' => 8,
            'labels' => { 'nodes' => [{ 'name' => 'feature' }] },
            'assignee' => nil
          },
          {
            'state' => { 'name' => 'In Progress', 'type' => 'started' },
            'priorityLabel' => 'High',
            'estimate' => 1,
            'labels' => { 'nodes' => [{ 'name' => 'tech-debt' }] },
            'assignee' => { 'name' => 'Bob' }
          }
        ]
      end

      it 'returns all distribution categories', :aggregate_failures do
        expect(result).to include(:status, :priority, :type, :size, :assignee)
      end

      it 'calculates status distribution' do
        expect(result[:status]).to eq({ 'In Progress' => 2, 'Backlog' => 1 })
      end

      it 'calculates priority distribution' do
        expect(result[:priority]).to eq({ 'High' => 2, 'Medium' => 1 })
      end

      it 'calculates type distribution', :aggregate_failures do
        expect(result[:type]['Bug']).to eq(1)
        expect(result[:type]['Feature']).to eq(1)
        expect(result[:type]['Tech Debt']).to eq(1)
      end

      it 'calculates size distribution', :aggregate_failures do
        expect(result[:size]['Small (1-2)']).to eq(1)
        expect(result[:size]['Medium (3-5)']).to eq(1)
        expect(result[:size]['Large (8+)']).to eq(1)
      end

      it 'calculates assignee distribution for in-progress issues' do
        # Only in-progress issues count for assignee distribution
        expect(result[:assignee]).to eq({ 'Alice' => 1, 'Bob' => 1 })
      end
    end

    context 'with no issues' do
      # Setup
      let(:issues) { [] }

      it 'returns empty distributions', :aggregate_failures do
        expect(result[:status]).to be_empty
        expect(result[:priority]).to be_empty
        expect(result[:assignee]).to be_empty
      end
    end
  end

  describe '#to_rows' do
    subject(:rows) { calculator.to_rows }

    # Setup
    let(:issues) do
      [{ 'state' => { 'name' => 'Backlog', 'type' => 'backlog' }, 'priorityLabel' => 'High' }]
    end

    it 'returns rows in expected format' do
      expect(rows).to all(satisfy do |row|
        # Date, Category, Metric Name, Value
        row[0] == today.to_s &&
          row[1].is_a?(String) &&
          row[2].is_a?(String) &&
          (row[3].is_a?(Numeric) || (row[1] == 'type_breakdown' && row[3].is_a?(String)))
      end)
    end

    it 'includes status distribution rows' do
      status_rows = rows.select { |r| r[1] == 'status' }
      expect(status_rows).not_to be_empty
    end
  end

  describe '#backlog_metrics' do
    subject(:metrics) { calculator.backlog_metrics }

    context 'with backlog issues' do
      # Setup
      let(:issues) do
        [
          {
            'createdAt' => '2024-11-25T10:00:00Z', # 10 days ago
            'state' => { 'type' => 'backlog' }
          },
          {
            'createdAt' => '2024-11-30T10:00:00Z', # 5 days ago
            'state' => { 'type' => 'backlog' }
          }
        ]
      end

      it 'calculates median backlog age' do
        # (10 + 5) / 2 = 7.5 days (approximately, depends on time)
        expect(metrics[:median_backlog_age_days]).to be_within(1).of(7.5)
      end
    end

    context 'with no backlog issues' do
      # Setup
      let(:issues) do
        [{ 'createdAt' => '2024-12-01T10:00:00Z', 'state' => { 'type' => 'started' } }]
      end

      it 'returns zero' do
        expect(metrics[:median_backlog_age_days]).to eq(0)
      end
    end
  end

  describe 'issue type classification' do
    let(:base_issue) do
      {
        'state' => { 'name' => 'Backlog', 'type' => 'backlog' },
        'priorityLabel' => nil,
        'estimate' => nil,
        'assignee' => nil
      }
    end

    context 'with bug label variations' do
      it 'classifies issues with bug label as Bug' do
        issue = base_issue.merge('labels' => { 'nodes' => [{ 'name' => 'bug' }] })
        result = described_class.new([issue]).calculate
        expect(result[:type]['Bug']).to eq(1)
      end

      it 'classifies issues with hotfix label as Bug' do
        issue = base_issue.merge('labels' => { 'nodes' => [{ 'name' => 'hotfix' }] })
        result = described_class.new([issue]).calculate
        expect(result[:type]['Bug']).to eq(1)
      end

      it 'classifies issues with fix label as Bug' do
        issue = base_issue.merge('labels' => { 'nodes' => [{ 'name' => 'fix' }] })
        result = described_class.new([issue]).calculate
        expect(result[:type]['Bug']).to eq(1)
      end
    end

    context 'with tech debt label variations' do
      it 'classifies issues with tech-debt label as Tech Debt' do
        issue = base_issue.merge('labels' => { 'nodes' => [{ 'name' => 'tech-debt' }] })
        result = described_class.new([issue]).calculate
        expect(result[:type]['Tech Debt']).to eq(1)
      end

      it 'classifies issues with refactor label as Tech Debt' do
        issue = base_issue.merge('labels' => { 'nodes' => [{ 'name' => 'refactor' }] })
        result = described_class.new([issue]).calculate
        expect(result[:type]['Tech Debt']).to eq(1)
      end
    end

    context 'with feature label variations' do
      it 'classifies issues with enhancement label as Feature' do
        issue = base_issue.merge('labels' => { 'nodes' => [{ 'name' => 'enhancement' }] })
        result = described_class.new([issue]).calculate
        expect(result[:type]['Feature']).to eq(1)
      end
    end

    context 'with no matching labels' do
      it 'classifies as Other' do
        issue = base_issue.merge('labels' => { 'nodes' => [{ 'name' => 'random-label' }] })
        result = described_class.new([issue]).calculate
        expect(result[:type]['Other']).to eq(1)
      end
    end

    context 'with no labels' do
      it 'classifies as Other' do
        issue = base_issue.merge('labels' => { 'nodes' => [] })
        result = described_class.new([issue]).calculate
        expect(result[:type]['Other']).to eq(1)
      end
    end

    context 'with nil labels' do
      it 'classifies as Other' do
        issue = base_issue.merge('labels' => nil)
        result = described_class.new([issue]).calculate
        expect(result[:type]['Other']).to eq(1)
      end
    end
  end
end

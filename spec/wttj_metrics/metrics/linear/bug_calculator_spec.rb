# frozen_string_literal: true

RSpec.describe WttjMetrics::Metrics::Linear::BugCalculator do
  subject(:calculator) { described_class.new(issues, today: today) }

  # Setup
  let(:today) { Date.new(2024, 12, 5) }
  let(:issues) { [] }

  describe '#calculate' do
    subject(:result) { calculator.calculate }

    context 'with bug issues' do
      # Setup
      let(:issues) do
        [
          # Open bug
          {
            'createdAt' => '2024-11-15T10:00:00Z',
            'state' => { 'type' => 'started' },
            'priorityLabel' => 'High',
            'labels' => { 'nodes' => [{ 'name' => 'bug' }] }
          },
          # Closed bug
          {
            'createdAt' => '2024-11-20T10:00:00Z',
            'completedAt' => '2024-11-25T10:00:00Z',
            'state' => { 'type' => 'completed' },
            'priorityLabel' => 'Medium',
            'labels' => { 'nodes' => [{ 'name' => 'Bug' }] }
          },
          # Non-bug issue
          {
            'createdAt' => '2024-11-10T10:00:00Z',
            'state' => { 'type' => 'backlog' },
            'labels' => { 'nodes' => [{ 'name' => 'feature' }] }
          }
        ]
      end

      it 'counts total bugs' do
        expect(result[:total]).to eq(2)
      end

      it 'counts open bugs' do
        expect(result[:open]).to eq(1)
      end

      it 'counts closed bugs' do
        expect(result[:closed]).to eq(1)
      end

      it 'calculates bug ratio' do
        # 2 bugs out of 3 issues = 66.7%
        expect(result[:bug_ratio]).to be_within(0.1).of(66.7)
      end

      it 'calculates median resolution days' do
        # 5 days for the closed bug
        expect(result[:median_resolution_days]).to eq(5.0)
      end

      it 'groups open bugs by priority' do
        expect(result[:by_priority]).to eq({ 'High' => 1 })
      end
    end

    context 'with bugs created in last 30 days' do
      # Setup
      let(:issues) do
        [
          {
            'createdAt' => '2024-11-10T10:00:00Z', # Within 30 days
            'state' => { 'type' => 'started' },
            'labels' => { 'nodes' => [{ 'name' => 'bug' }] }
          },
          {
            'createdAt' => '2024-10-01T10:00:00Z', # Outside 30 days
            'state' => { 'type' => 'backlog' },
            'labels' => { 'nodes' => [{ 'name' => 'bug' }] }
          }
        ]
      end

      it 'counts bugs created in last 30 days' do
        expect(result[:created_last_30d]).to eq(1)
      end
    end

    context 'with bugs without priority' do
      # Setup
      let(:issues) do
        [
          {
            'createdAt' => '2024-11-15T10:00:00Z',
            'state' => { 'type' => 'started' },
            'priorityLabel' => nil,
            'labels' => { 'nodes' => [{ 'name' => 'bug' }] }
          }
        ]
      end

      it 'categorizes as No priority' do
        expect(result[:by_priority]).to eq({ 'No priority' => 1 })
      end
    end

    context 'with closed bugs without completedAt' do
      # Setup
      let(:issues) do
        [
          {
            'createdAt' => '2024-11-20T10:00:00Z',
            'completedAt' => nil,
            'state' => { 'type' => 'completed' },
            'labels' => { 'nodes' => [{ 'name' => 'bug' }] }
          }
        ]
      end

      it 'excludes from bugs_closed_last_30d' do
        expect(result[:closed_last_30d]).to eq(0)
      end

      it 'excludes from resolution time calculation' do
        expect(result[:median_resolution_days]).to eq(0)
      end
    end

    context 'with no issues' do
      # Setup
      let(:issues) { [] }

      it 'returns zero bug ratio' do
        expect(result[:bug_ratio]).to eq(0)
      end
    end

    context 'with no bugs' do
      # Setup
      let(:issues) do
        [{ 'createdAt' => '2024-12-01T10:00:00Z', 'state' => { 'type' => 'backlog' }, 'labels' => { 'nodes' => [] } }]
      end

      it 'returns zero counts', :aggregate_failures do
        expect(result[:total]).to eq(0)
        expect(result[:open]).to eq(0)
        expect(result[:closed]).to eq(0)
      end
    end
  end

  describe '#to_rows' do
    subject(:rows) { calculator.to_rows }

    # Setup
    let(:issues) { [] }

    it 'returns rows in expected format' do
      bug_rows = rows.select { |r| r[1] == 'bugs' }

      expect(bug_rows).to all(match([today.to_s, 'bugs', kind_of(String), kind_of(Numeric)]))
    end

    it 'includes all bug metrics' do
      metric_names = rows.map { |r| r[2] }

      expect(metric_names).to include(
        'total_bugs',
        'open_bugs',
        'closed_bugs',
        'median_bug_resolution_days',
        'bug_ratio'
      )
    end
  end
end

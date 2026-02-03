# frozen_string_literal: true

RSpec.describe WttjMetrics::Services::PresenterMapper do
  describe '.map_to_presenters' do
    let(:presenter_class) { WttjMetrics::Presenters::FlowMetricPresenter }
    let(:metrics) do
      [
        { metric: 'median_cycle_time_days', value: 10.5 },
        { metric: 'median_lead_time_days', value: 24.3 }
      ]
    end

    it 'maps each metric to a presenter instance' do
      result = described_class.map_to_presenters(metrics, presenter_class)

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(presenter_class))
    end

    it 'passes each metric to the presenter constructor' do
      result = described_class.map_to_presenters(metrics, presenter_class)

      expect(result.first.name).to eq('median_cycle_time_days')
      expect(result.last.name).to eq('median_lead_time_days')
    end

    context 'when metrics is nil' do
      it 'returns empty array' do
        result = described_class.map_to_presenters(nil, presenter_class)
        expect(result).to eq([])
      end
    end

    context 'when metrics is empty' do
      it 'returns empty array' do
        result = described_class.map_to_presenters([], presenter_class)
        expect(result).to eq([])
      end
    end

    context 'with different presenter classes' do
      let(:bug_metrics) do
        [
          { metric: 'total_bugs', value: 150 },
          { metric: 'open_bugs', value: 42 }
        ]
      end

      it 'works with BugMetricPresenter' do
        result = described_class.map_to_presenters(
          bug_metrics,
          WttjMetrics::Presenters::BugMetricPresenter
        )

        expect(result).to all(be_a(WttjMetrics::Presenters::BugMetricPresenter))
      end
    end
  end

  describe '.map_hash_to_presenters' do
    let(:presenter_class) { WttjMetrics::Presenters::CyclePresenter }
    let(:cycles_by_team) do
      {
        'ATS' => [
          { id: 1, name: 'Sprint 1', status: 'completed' },
          { id: 2, name: 'Sprint 2', status: 'active' }
        ],
        'Platform' => [
          { id: 3, name: 'Sprint 3', status: 'completed' }
        ]
      }
    end

    it 'maps hash values to presenter instances' do
      result = described_class.map_hash_to_presenters(cycles_by_team, presenter_class)

      expect(result).to be_a(Hash)
      expect(result.keys).to eq(%w[ATS Platform])
      expect(result['ATS']).to all(be_a(presenter_class))
      expect(result['Platform']).to all(be_a(presenter_class))
    end

    it 'preserves the hash structure' do
      result = described_class.map_hash_to_presenters(cycles_by_team, presenter_class)

      expect(result['ATS'].size).to eq(2)
      expect(result['Platform'].size).to eq(1)
    end

    it 'passes each item to the presenter constructor' do
      result = described_class.map_hash_to_presenters(cycles_by_team, presenter_class)

      expect(result['ATS'].first.name).to eq('Sprint 1')
      expect(result['ATS'].last.name).to eq('Sprint 2')
    end

    context 'when hash is nil' do
      it 'returns empty hash' do
        result = described_class.map_hash_to_presenters(nil, presenter_class)
        expect(result).to eq({})
      end
    end

    context 'when hash is empty' do
      it 'returns empty hash' do
        result = described_class.map_hash_to_presenters({}, presenter_class)
        expect(result).to eq({})
      end
    end

    context 'when hash has teams with varying numbers of cycles' do
      let(:mixed_hash) do
        {
          'Team1' => [
            { name: 'Sprint 1', status: 'completed' },
            { name: 'Sprint 2', status: 'active' }
          ],
          'Team2' => [
            { name: 'Sprint A', status: 'active' }
          ]
        }
      end

      it 'correctly maps arrays of different sizes' do
        result = described_class.map_hash_to_presenters(mixed_hash, presenter_class)

        expect(result['Team1'].size).to eq(2)
        expect(result['Team2'].size).to eq(1)
        expect(result['Team1'].first.name).to eq('Sprint 1')
        expect(result['Team2'].first.name).to eq('Sprint A')
      end
    end
  end

  describe '.map_team_stats_to_presenters' do
    let(:presenter_class) { WttjMetrics::Presenters::BugTeamPresenter }
    let(:bugs_by_team) do
      {
        'ATS' => { created: 150, closed: 120, open: 30, mttr: 5.5 },
        'Platform' => { created: 80, closed: 75, open: 5, mttr: 2.3 }
      }
    end

    it 'maps team stats to presenter instances' do
      result = described_class.map_team_stats_to_presenters(bugs_by_team, presenter_class)

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(presenter_class))
    end

    it 'passes team name and stats to presenter constructor' do
      result = described_class.map_team_stats_to_presenters(bugs_by_team, presenter_class)

      first_presenter = result.first
      expect(first_presenter.name).to eq('ATS')
      expect(first_presenter.created).to eq(150)
      expect(first_presenter.closed).to eq(120)
      expect(first_presenter.open).to eq(30)
    end

    it 'maintains order of teams' do
      result = described_class.map_team_stats_to_presenters(bugs_by_team, presenter_class)

      expect(result.map(&:name)).to eq(%w[ATS Platform])
    end

    context 'when hash is nil' do
      it 'returns empty array' do
        result = described_class.map_team_stats_to_presenters(nil, presenter_class)
        expect(result).to eq([])
      end
    end

    context 'when hash is empty' do
      it 'returns empty array' do
        result = described_class.map_team_stats_to_presenters({}, presenter_class)
        expect(result).to eq([])
      end
    end

    context 'with single team' do
      let(:single_team) do
        { 'Sourcing' => { created: 50, closed: 45, open: 5, mttr: 3.2 } }
      end

      it 'creates single presenter' do
        result = described_class.map_team_stats_to_presenters(single_team, presenter_class)

        expect(result.size).to eq(1)
        expect(result.first.name).to eq('Sourcing')
      end
    end
  end

  describe 'integration scenarios' do
    context 'when used in report generation pipeline' do
      let(:flow_metrics) do
        [
          { metric: 'median_cycle_time_days', value: 10.0 },
          { metric: 'median_lead_time_days', value: 24.4 },
          { metric: 'weekly_throughput', value: 90 },
          { metric: 'current_wip', value: 137 }
        ]
      end

      it 'creates presenters that can be used in templates' do
        presenters = described_class.map_to_presenters(
          flow_metrics,
          WttjMetrics::Presenters::FlowMetricPresenter
        )

        # Verify presenters have the methods templates expect
        expect(presenters.first).to respond_to(:label)
        expect(presenters.first).to respond_to(:value)
        expect(presenters.first).to respond_to(:unit)
        expect(presenters.first).to respond_to(:tooltip)
      end
    end

    context 'when chaining with other operations' do
      it 'allows further processing of mapped results' do
        metrics = [
          { metric: 'metric1', value: 10 },
          { metric: 'metric2', value: 20 }
        ]

        result = described_class.map_to_presenters(
          metrics,
          WttjMetrics::Presenters::FlowMetricPresenter
        )

        # Can further filter or transform
        filtered = result.select { |p| p.value.to_i > 15 }
        expect(filtered.size).to eq(1)
      end
    end
  end
end

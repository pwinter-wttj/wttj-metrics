# frozen_string_literal: true

require 'tempfile'

RSpec.describe WttjMetrics::Reports::Github::ExcelReportBuilder do
  subject(:builder) { described_class.new(report_data) }

  let(:temp_file) { Tempfile.new(['github_report', '.xlsx']) }
  let(:report_data) do
    {
      today: '2024-12-09',
      metrics: {
        median_time_to_merge: 2.5,
        total_merged: 100,
        median_reviews: 3.2,
        median_comments: 5.1,
        median_time_to_first_review: 1.1,
        median_additions: 150,
        median_deletions: 50,
        median_changed_files: 4.5,
        median_commits: 2.1
      },
      daily_breakdown: {
        labels: %w[2024-12-01 2024-12-02],
        datasets: {
          merged: [5, 8],
          closed: [1, 0],
          open: [10, 12],
          median_time_to_merge: [24.0, 12.0],
          median_reviews: [3.0, 4.0],
          median_comments: [5.0, 6.0],
          median_additions: [100, 200],
          median_deletions: [20, 30],
          median_time_to_first_review: [10.0, 5.0]
        }
      },
      raw_data: [
        { 'date' => '2024-12-01', 'category' => 'github', 'metric' => 'merged', 'value' => 5 }
      ]
    }
  end

  after do
    temp_file.close
    temp_file.unlink
  end

  describe '#build' do
    it 'creates an Excel file' do
      builder.build(temp_file.path)
      expect(File.exist?(temp_file.path)).to be true
      expect(File.size(temp_file.path)).to be > 0
    end

    context 'with mocked axlsx' do
      let(:package) { instance_double(Axlsx::Package) }
      let(:workbook) { instance_double(Axlsx::Workbook) }
      let(:sheet) { instance_double(Axlsx::Worksheet) }
      let(:styles) { instance_double(Axlsx::Styles) }

      before do
        allow(Axlsx::Package).to receive(:new).and_return(package)
        allow(package).to receive(:workbook).and_return(workbook)
        allow(package).to receive(:serialize)
        allow(workbook).to receive(:styles).and_return(styles)
        allow(styles).to receive(:add_style).and_return(1)
        allow(workbook).to receive(:add_worksheet).and_yield(sheet)
        allow(sheet).to receive(:add_row)
        allow(sheet).to receive(:merge_cells)
        allow(sheet).to receive(:column_widths)
      end

      it 'adds key metrics rows with correct formatting' do
        builder.build('dummy.xlsx')

        # Float value with unit
        expect(sheet).to have_received(:add_row).with(['Median Time to Merge', '2.5 days'])
        # Integer value with empty unit
        expect(sheet).to have_received(:add_row).with(['Total Merged PRs', '100'])
        # Float value with empty unit
        expect(sheet).to have_received(:add_row).with(['Median Reviews/PR', '3.2'])
        # Integer value with unit
        expect(sheet).to have_received(:add_row).with(['Median Additions/PR', '150 lines'])
      end
    end
  end
end

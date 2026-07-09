require "rails_helper"

RSpec.describe ImportDispatchJob do
  it "counts rows and fans out one batch job per batch" do
    rows = Import::BATCH_SIZE * 2 + 1
    import = create(:import, csv_content: valid_csv(rows))

    described_class.new.perform(import.id)

    import.reload
    expect(import.total_rows).to eq(rows)
    expect(import.status).to eq("processing")
    expect(ImportBatchJob.jobs.size).to eq(3)
    expect(ImportBatchJob.jobs.map { |j| j["args"] })
      .to contain_exactly([import.id, 0], [import.id, 1], [import.id, 2])
  end

  it "completes an empty file immediately without enqueuing batches" do
    import = create(:import, csv_content: "name,email\n")

    described_class.new.perform(import.id)

    expect(import.reload.status).to eq("completed")
    expect(ImportBatchJob.jobs).to be_empty
  end

  it "is a no-op for imports that already finished" do
    import = create(:import, status: "completed", csv_content: valid_csv(5))

    described_class.new.perform(import.id)

    expect(ImportBatchJob.jobs).to be_empty
  end
end

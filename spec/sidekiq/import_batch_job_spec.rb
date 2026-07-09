require "rails_helper"

RSpec.describe ImportBatchJob do
  describe "idempotency under at-least-once delivery" do
    it "produces identical results when the same batch runs twice" do
      import = create(:import, status: "processing", total_rows: 3,
                               csv_content: valid_csv(3))

      described_class.new.perform(import.id, 0)
      expect(import.imported_contacts.count).to eq(3)

      # Simulate Sidekiq redelivering the same job (e.g. worker died after
      # the upsert but before the ack).
      expect {
        described_class.new.perform(import.id, 0)
      }.not_to change { import.imported_contacts.count }

      import.reload
      expect(import.processed_rows).to eq(3)
      expect(import.status).to eq("completed")
    end

    it "does not double-count progress when a batch is retried" do
      import = create(:import, status: "processing", total_rows: 3,
                               csv_content: valid_csv(3))

      3.times { described_class.new.perform(import.id, 0) }

      expect(import.reload.processed_rows).to eq(3)
      expect(import.progress_percentage).to eq(100)
    end
  end

  describe "error handling" do
    let(:csv_with_errors) do
      <<~CSV
        name,email
        Alice,alice@example.com
        ,missing-name@example.com
        Bob,not-an-email
        Cara,cara@example.com
      CSV
    end

    it "records failures without aborting the batch" do
      import = create(:import, status: "processing", total_rows: 4,
                               csv_content: csv_with_errors)

      described_class.new.perform(import.id, 0)
      import.reload

      expect(import.imported_contacts.pluck(:email))
        .to contain_exactly("alice@example.com", "cara@example.com")
      expect(import.import_errors.pluck(:message))
        .to contain_exactly("Name is missing", "Email is not a valid address")
      expect(import.status).to eq("completed_with_errors")
    end

    it "records the same errors, not duplicates, when retried" do
      import = create(:import, status: "processing", total_rows: 4,
                               csv_content: csv_with_errors)

      2.times { described_class.new.perform(import.id, 0) }

      expect(import.reload.failed_rows).to eq(2)
      expect(import.import_errors.count).to eq(2)
    end

    it "keeps 1-based CSV line numbers including the header" do
      import = create(:import, status: "processing", total_rows: 4,
                               csv_content: csv_with_errors)

      described_class.new.perform(import.id, 0)

      # "missing name" is the 3rd line of the file
      expect(import.import_errors.order(:row_number).first.row_number).to eq(3)
    end
  end

  describe "batching" do
    it "only touches rows inside its own batch" do
      rows = Import::BATCH_SIZE + 5
      import = create(:import, status: "processing", total_rows: rows,
                               csv_content: valid_csv(rows))

      described_class.new.perform(import.id, 1)

      expect(import.imported_contacts.count).to eq(5)
      expect(import.reload.status).to eq("processing")
    end

    it "completes the import when the final batch lands" do
      rows = Import::BATCH_SIZE + 5
      import = create(:import, status: "processing", total_rows: rows,
                               csv_content: valid_csv(rows))

      described_class.new.perform(import.id, 0)
      described_class.new.perform(import.id, 1)

      import.reload
      expect(import.processed_rows).to eq(rows)
      expect(import.status).to eq("completed")
    end
  end
end

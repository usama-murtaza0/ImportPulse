require "rails_helper"

RSpec.describe Import do
  describe "#progress_percentage" do
    it "is 0 for an import with no counted rows yet" do
      expect(build(:import).progress_percentage).to eq(0)
    end

    it "includes both successes and failures as progress" do
      import = build(:import, total_rows: 10, processed_rows: 6, failed_rows: 2)
      expect(import.progress_percentage).to eq(80)
    end
  end

  describe "#refresh_progress!" do
    it "derives counters from persisted rows rather than accumulating" do
      import = create(:import, status: "processing", total_rows: 2)
      create_list_of_contacts(import, 2)

      # Even if counters were corrupted, refresh derives the truth.
      import.update_columns(processed_rows: 99)
      import.refresh_progress!

      expect(import.processed_rows).to eq(2)
      expect(import.status).to eq("completed")
    end

    it "marks completed_with_errors when failures exist" do
      import = create(:import, status: "processing", total_rows: 2)
      create_list_of_contacts(import, 1)
      import.import_errors.create!(row_number: 3, message: "Email is missing")

      import.refresh_progress!

      expect(import.status).to eq("completed_with_errors")
    end
  end

  def create_list_of_contacts(import, count)
    count.times do |i|
      import.imported_contacts.create!(row_number: i + 2, name: "P#{i}",
                                       email: "p#{i}@example.com")
    end
  end
end

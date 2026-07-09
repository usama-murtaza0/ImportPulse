require "rails_helper"

RSpec.describe "Imports", type: :request do
  describe "POST /imports" do
    it "stores the file and enqueues the dispatch job" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new(valid_csv(3)), "text/csv", original_filename: "contacts.csv"
      )

      expect {
        post imports_path, params: { file: file }
      }.to change(Import, :count).by(1)

      import = Import.last
      expect(import.filename).to eq("contacts.csv")
      expect(File.exist?(import.file_path)).to be(true)
      expect(ImportDispatchJob.jobs.map { |j| j["args"] }).to eq([[import.id]])
      expect(response).to redirect_to(import_path(import))
    end

    it "rejects non-CSV uploads" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("hi"), "text/plain", original_filename: "notes.txt"
      )

      expect {
        post imports_path, params: { file: file }
      }.not_to change(Import, :count)

      expect(ImportDispatchJob.jobs).to be_empty
    end
  end

  describe "GET /imports/:id" do
    it "renders progress and errors" do
      import = create(:import, status: "processing", total_rows: 4,
                               processed_rows: 1, failed_rows: 1)
      import.import_errors.create!(row_number: 3, message: "Email is missing")

      get import_path(import)

      expect(response.body).to include("Email is missing")
      expect(response.body).to include("50%")
    end
  end
end

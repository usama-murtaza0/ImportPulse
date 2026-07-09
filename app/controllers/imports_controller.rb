class ImportsController < ApplicationController
  def index
    @imports = Import.recent_first
  end

  def show
    @import = Import.find(params[:id])
    @import_errors = @import.import_errors.order(:row_number)
  end

  def create
    file = params[:file]

    if file.blank? || File.extname(file.original_filename).downcase != ".csv"
      redirect_to imports_path, alert: "Please choose a CSV file." and return
    end

    import = Import.create!(filename: file.original_filename, status: "pending")

    import.file_path.dirname.mkpath
    File.binwrite(import.file_path, file.read)

    ImportDispatchJob.perform_async(import.id)

    redirect_to import_path(import), notice: "Import queued — progress updates live."
  end
end

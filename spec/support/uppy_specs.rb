# frozen_string_literal: true

# Emulates Uppy uploading one file (https://stackoverflow.com/a/41054559/446681)
#
# Notice that we cannot use RSpec built-in `attach_file` because we are
# not using the browser's standard upload file button.
def attach_file_via_uppy(file_name)
  Rack::Test::UploadedFile.new(File.open(file_name))
end

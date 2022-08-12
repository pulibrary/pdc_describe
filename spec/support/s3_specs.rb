# frozen_string_literal: true
def stub_s3(data: [])
  fake_s3_query = double(S3QueryService, data_profile: { objects: data, ok: true })
  S3QueryService.stub(:new).and_return(fake_s3_query)
end

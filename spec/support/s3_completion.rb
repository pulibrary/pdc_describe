# frozen_string_literal: true

def build_fake_s3_completion
  fake_copy_object_result = instance_double(Aws::S3::Types::CopyObjectResult, etag: "\"abc123etagetag\"")
  fake_copy = instance_double(Aws::S3::Types::CopyObjectOutput, copy_object_result: fake_copy_object_result)
  fake_http_resp = instance_double(Seahorse::Client::Http::Response, status_code: 200, on_error: nil)
  fake_http_req = instance_double(Seahorse::Client::Http::Request)
  fake_request_context = instance_double(Seahorse::Client::RequestContext, http_response: fake_http_resp, http_request: fake_http_req)
  Seahorse::Client::Response.new(context: fake_request_context, data: fake_copy)
end

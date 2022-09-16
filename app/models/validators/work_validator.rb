# frozen_string_literal: true

module Validators
  class WorkValidator < ActiveModel::Validator
    def validate(work)
      # This is expensive, but without listening to WebHooks, there is no asynchronous method for determining if the S3 Bucket Objects need to be resynchronized
      # Attaching S3 Objects without the Work first being persisted is not supported by ActiveStorage
      # Update the uploads attachments using S3 Resources
      work.attach_s3_resources if work.persisted? && !work.attaching_s3_objects?

      work.save_pre_curation_uploads unless work.approved?
    end
  end
end

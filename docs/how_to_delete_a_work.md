Deleting a work and its content on Amazon is not as easy as running `work.destroy`.
These steps assume the work is assigned to a variable called `work`.
1. Delete the pre curation uploads
   * `work.pre_curation_uploads.each(&:destroy)`
1. Delete the post curation uploads 
   * ```
     service = S3QueryService.new(work, false)
     work.post_curation_uploads.each{|upload| service.client.delete_object({ bucket: service.bucket_name, key: upload.key})}
     ```
1. Delete the UserWork records
   * `UserWork.where(work_id: work.id).each(&:destroy)` 
1. Finally destroy the work
   * `work.destroy`

Full script below...
```ruby
work.pre_curation_uploads.each(&:destroy)
service = S3QueryService.new(work, false)
work.post_curation_uploads.each{|upload| service.client.delete_object({ bucket: service.bucket_name, key: upload.key})}
UserWork.where(work_id: work.id).each(&:destroy)
work.destroy
```

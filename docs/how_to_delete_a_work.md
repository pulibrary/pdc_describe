Deleting a work and its content on Amazon is not as easy as running `work.destroy`.
These steps assume the work is assigned to a variable called `work`.
1. Delete the pre curation uploads
   * ```
     service = S3QueryService.new(work, false)
     work.pre_curation_uploads_fast.each{|upload| service.client.delete_object({ bucket: service.bucket_name, key: upload.key})}
     ```
1. Delete the post curation uploads 
   * ```
     service = S3QueryService.new(work, false)
     work.post_curation_uploads.each{|upload| service.client.delete_object({ bucket: service.bucket_name, key: upload.key})}
     ```
1. Finally destroy the work
   * `work.destroy`

Full script below...
```ruby
service = S3QueryService.new(work, false)
work.pre_curation_uploads_fast.each{|upload| service.client.delete_object({ bucket: service, bucket_name, key: upload.key})}
work.post_curation_uploads.each{|upload| service.client.delete_object({ bucket: service.bucket_name, key: upload.key})}
work.destroy
```

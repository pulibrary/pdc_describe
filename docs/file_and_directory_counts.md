# File and directory counts in PDC

## Introduction

Curators compare the file count shown in PDC Describe with the count shown in PDC Discovery after publication. Matching counts is a check that the file transfer completed as expected (for example, after Globus deposit, or when filenames or volume cause timeouts).

This document explains how those numbers are calculated, why they can differ, and what to expect in each environment. It does not change application behavior; it records how counting works today.

## Short answers

1. **PDC Discovery** does not add a separate folder tally. It displays every object in the indexed file list (post-curation S3 objects harvested from Describe).
2. **PDC Describe** counts files **and** directory placeholders together. The work page heading is “Files or Directories in … storage”.
3. **They use the same listing rule** (every S3 object under the work prefix) but **not always the same bucket or the same objects**. Describe’s pre-curation list often includes empty directory markers that are never copied to post-curation. Discovery only sees post-curation (and nothing while a work is embargoed).

## How S3 represents files and folders

Amazon S3 does not have real directories. A “folder” is a zero-byte object whose key ends with `/`. Describe treats a key that ends with `/` as a folder (`S3File#is_folder`).

The file list is built from `list_objects_v2` **contents** only (not `common_prefixes`). A folder appears in the count only if that placeholder object exists in the bucket.

Work objects live under the prefix `{doi}/{work_id}/`.

## How PDC Describe calculates the count

On the work show/edit page, the number next to “Files or Directories” comes from an AJAX request to `/works/:id/file-list`.

1. `Work#file_list` loads S3 objects for the work.
2. If the work is **approved**, it lists **post-curation** objects; otherwise it lists **pre-curation** objects.
3. `WorksController#file_list_ajax_response` sets `total_file_count` to `files.count` — every object in that list, files and folder keys included.

A README created through the Describe web form is a normal file in S3. Once it exists, it is included in the count like any other file.

Migration messages (Dataspace) report file count and directory count **separately**. That is only for migration activity text, not the number on the work file table.

## How PDC Discovery calculates the count

Discovery does not query S3 for the public file table. It indexes JSON harvested from Describe (`Work#as_json` → `files`).

1. `Work#files_as_json` returns `[]` if the work is embargoed.
2. Otherwise it maps **post-curation** uploads to `{ filename, size, display_size, url }`.
3. Discovery stores that payload in Solr (`pdc_describe_json_ss`) and `SolrDocument#files` parses the `files` array.
4. The public file table is a DataTables grid over that array. The “of N entries” figure is `files.length`.

Discovery does not filter on `is_folder`. Folder keys would appear only if they exist in post-curation and were harvested.

Implementation in Discovery: `app/models/solr_document.rb` (`#files`) and `app/controllers/catalog_controller.rb` (`#file_list`). Repo: [pulibrary/pdc_discovery](https://github.com/pulibrary/pdc_discovery).

## Why pre-curation and post-curation counts can differ

Publication copies objects from the pre-curation bucket to post-curation (or embargo) in `WorkPublishService`:

1. List all objects in pre-curation (`client_s3_files`).
2. Copy **files only** (`reject(&:is_folder)`) via `ApprovedFileMoveJob`.
3. Do **not** copy directory placeholders. After files have moved, `EmptyDirectoryDeleteJob` deletes empty directory keys from pre-curation.

So a pre-curation Describe count can be higher than the Discovery (post-curation) count by the number of directory placeholders that existed at deposit. The files inside those folders can still match exactly.

That pattern showed up in the investigation for DOI [10.34770/14zc-5c22](https://doi.org/10.34770/14zc-5c22) (Describe work [679](https://datacommons.princeton.edu/describe/works/679)): Globus transfer of contents succeeded, but the displayed counts did not match because directory markers were not part of the published object list.

## Curation workflow

Use this when checking counts at the end of publication:

1. In Describe, note the number labeled **Files or Directories** while the work is still in pre-curation (awaiting approval). That number includes folder placeholders.
2. After approval, wait for file-move jobs to finish (Sidekiq) and for Discovery to harvest/index the work.
3. In Describe on the approved work, the same heading now lists **post-curation** storage. That list should align with what Discovery will index (embargo excepted).
4. In Discovery, open the dataset and compare the file table “entries” count to the post-curation Describe count, not to the earlier pre-curation count.
5. If folder contents match in Globus/S3 but the numbers differ by a small integer, count how many keys in pre-curation end with `/`. That difference is expected.

If actual **files** are missing (not just folder keys), treat it as a transfer problem: check Sidekiq (`ApprovedFileMoveJob`), Rails logs, and the pre- vs post-curation buckets. See [sidekiq_jobs.md](sidekiq_jobs.md).

## Environments

Logic is the same in staging and production. Bucket names come from `PULS3Client` configuration (pre-curation, post-curation, embargo).

| Environment | Describe | Discovery |
| --- | --- | --- |
| Production | https://pdc-describe-prod.princeton.edu/describe | https://datacommons.princeton.edu/discovery |
| Staging | staging Describe host | staging Discovery host |

Discovery only shows files after the work is approved (or force-harvested) and indexed. Embargoed works harvest with an empty `files` array until release.

Re-index Discovery after publication if the file list looks stale (same process used after embargo changes; see [embargo.md](embargo.md)).

## References

- Issue: [Describe how files and directories are counted in PDC](https://github.com/pulibrary/pdc_describe/issues/2426)
- Related troubleshooting: [Troubleshoot files missing from move](https://github.com/pulibrary/pdc_describe/issues/2417)
- Example dataset: [https://doi.org/10.34770/14zc-5c22](https://doi.org/10.34770/14zc-5c22)
- Describe: `Work#file_list`, `WorksController#file_list_ajax_response`, `Work#files_as_json`, `S3QueryService#client_s3_files`, `WorkPublishService`, `EmptyDirectoryDeleteJob`, `S3File#is_folder`
- Describe UI: `app/views/works/_s3_resources.html.erb` (“Files or Directories”)
- Discovery: [pulibrary/pdc_discovery](https://github.com/pulibrary/pdc_discovery) `SolrDocument#files`, `CatalogController#file_list`
- Discovery ADR: `architectture-decisions/0001-indexing-file-list.md` in pdc_discovery

# frozen_string_literal: true
class UpdateSnapshotJob < ApplicationJob
  queue_as :low

  def perform(work_id:, last_snapshot_id:)
    work = Work.find(work_id)

    # do nothing if there was another snapshot saved to the work between when this one was queued and when it started
    #   Becuse this job can take so long lets not keep running it every time someone looks at the work
    #   Unless this is a completely new visit after the last queued job completed
    return if work.upload_snapshots.first&.id != last_snapshot_id

    work.reload_snapshots
  end
end

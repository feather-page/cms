module JobHelpers
  def perform_enqueued_jobs(&)
    old_perform_enqueued_jobs = ActiveJob::Base.queue_adapter.perform_enqueued_jobs
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true

    yield

    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = old_perform_enqueued_jobs
  end
end

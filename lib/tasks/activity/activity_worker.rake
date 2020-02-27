require_relative 'activity_utils'
require_relative 'task_definitions'
require 'logger'

region = 'us-west-2'
activity_arn = 'arn:aws:states:us-west-2:732052188396:activity:idseq-staging-process-background-task'

task activity_worker: :environment do
  logger = Logger.new(STDOUT)

  activity_worker_master = StepFunctions::ActivityWorkerMaster.new(
    activity_arn: activity_arn,
    workers_count: 1,
    pollers_count: 1,
    heartbeat_delay: 10
  )

  # Special handler for the SIGINT signal.
  # Set the status to draining.
  # The ActivityWorker will shutdown automatically after the current task is complete.
  Signal.trap('TERM') {
    activity_worker_master.kill_signal_received = true
  }

  # The start method takes as argument the block that is the actual logic of your custom activity.
  activity_worker_master.start do |input|
    if input['job_name'].nil?
      raise "job_name required"
    end

    if !TaskDefinitions.respond_to?(input['job_name'])
      raise "unknown job_name"
    end

    # Tasks should not return a value.
    # If the task has failed, an error should be thrown.
    # If the task completes, it is assumed to be successful.
    TaskDefinitions.send(input['job_name'], input)

    { result: :SUCCESS }
  end
end
# class ValidateBulkDownloadIdsService
#   SAMPLE_NO_PERMISSION_ERROR = "You do not have permission to access all of the selected samples. Please contact us for help.".freeze
#
#   def initialize(sample_ids, current_user)
#     @user = current_user
#     @input_sample_ids = sample_ids
#     @valid_sample_ids = []
#     @invalid_sample_ids = []
#     @unviewable_sample_ids = []
#     @valid_pipeline_run_ids = []
#
#     viewable_samples = viewable_sample_ids(@input_sample_ids, @user)
#   end
#
#   private
#
#   # Will raise errors if validation fails.
#   # Returns viewable samples for the sample ids in the bulk download.
#   def viewable_sample_ids(sample_ids, _user)
#     # Access control check.
#     viewable_samples = current_power.viewable_samples.where(id: sample_ids)
#     viewable_ids = viewable_samples.map(&:sample_id)
#     if viewable_ids.length != sample_ids.length
#       @unviewable_sample_ids = sample_ids - viewable_ids # using Ruby set difference
#     end
#
#     return viewable_samples
#   end
#
#   # Return all pipeline runs that have succeeded for given samples
#   # Only check the first pipeline run.
#   # samples should be an ActiveRecord relation
#   # If strict mode is turned on, error out even if one pipeline run did not succeed.
#   # Note: Does NOT do access control checks.
#   def get_sample_ids_with_successful_pipeline_runs(samples)
#     begin
#       # Gets the first pipeline runs for multiple samples in an efficient way.
#       created_dates = PipelineRun.select("sample_id, MAX(created_at) as created_at").where(sample_id: samples.pluck(:id)).group(:sample_id)
#       valid_pipeline_runs = PipelineRun
#                             .select(:finalized, :id, :job_status, :sample_id)
#                             .where("(sample_id, created_at) IN (?)", created_dates)
#                             .where(finalized: 1)
#
#       valid_pipeline_runs = valid_pipeline_runs.select(&:succeeded?)
#       valid_sample_ids = valid_pipeline_runs.map(&:sample_id)
#     rescue => e
#       LogUtil.log_err_and_airbrake("BulkDownloadsFailedEvent: Unexpected issue getting valid pipeline runs for samples: #{e}")
#       raise
#     end
#
#     # need to return valid pipeline runs and update invalid runs
#     return valid_sample_ids
#   end
# end

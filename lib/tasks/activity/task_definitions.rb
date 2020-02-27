require 'logger'

module TaskDefinitions
  def self.test_task(input)
    if input["sample_id"].nil?
      raise "sample_id required"
    end
    if input["new_sample_notes"].nil?
      raise "new_sample_notes required"
    end

    Sample.find(input["sample_id"]).update(sample_notes: input["new_sample_notes"])
  end

  def self.pause(input)
    logger = Logger.new(STDOUT)

    if input["pause_time"].nil?
      raise "pause_time required"
    end

    logger.info("About to sleep for #{input['pause_time'].to_i} seconds")

    sleep(input["pause_time"].to_i)
  end
end

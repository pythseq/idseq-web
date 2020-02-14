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
    if input["pause_time"].nil?
      raise "pause_time required"
    end

    sleep(input["pause_time"])
  end
end

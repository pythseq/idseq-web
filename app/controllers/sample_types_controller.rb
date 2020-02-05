class SampleTypesController < ApplicationController
  skip_before_action :authenticate_user!

  # GET /sample_types.json
  def index
    respond_to do |format|
      format.json { render json: SampleType.all }
    end
  end
end

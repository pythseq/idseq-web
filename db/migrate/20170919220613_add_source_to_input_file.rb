class AddSourceToInputFile < ActiveRecord::Migration[5.1]
  def change
    add_column :input_files, :source, :text
  end
end

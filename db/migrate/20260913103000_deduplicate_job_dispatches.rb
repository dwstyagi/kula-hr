class DeduplicateJobDispatches < ActiveRecord::Migration[8.1]
  def change
    add_index :job_dispatches, [ :job_class, :arguments ], unique: true, name: :index_dispatches_unique_work
  end
end

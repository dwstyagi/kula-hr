# Tests tagged with :with_cache use MemoryStore instead of the null_store
# configured in config/environments/test.rb. This allows testing code paths
# that depend on Rails.cache reads/writes (e.g. the import preview flow).
RSpec.configure do |config|
  config.around(:each, :with_cache) do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end
end

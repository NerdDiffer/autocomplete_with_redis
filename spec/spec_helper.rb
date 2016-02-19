require 'dictionary'

# WARNING: Running tests will clear whatever you have on the key:
# 'autocomplete_with_redis_test'

RSpec.configure do |config|
  TEST_KEY = 'autocomplete_with_redis_test'

  config.before(:suite) do
    Redis.new.del(TEST_KEY)
  end

  config.order = 'rand'
  config.fail_fast = false
  config.color = true
  config.default_formatter = 'doc' if config.files_to_run.one?
end

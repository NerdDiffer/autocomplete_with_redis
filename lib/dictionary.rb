require 'redis'
require_relative 'dictionary/refresh'
require_relative 'dictionary/search'

# Redis autocomplete example
class Dictionary
  attr_reader :redis, :set_key, :file_name

  include Refresh

  def initialize(set_key)
    @redis = Redis.new
    @set_key = set_key
    @file_name = 'female-names.txt'

    refresh
  end

  # Populate the sorted set (or refresh if it already exists).
  def refresh
    if redis.exists(set_key)
      delete_set_key!
      puts "Deleted redis key: #{set_key}. Refreshing now."
    end

    puts 'Loading entries into Redis DB'
    populate_set
  end

  def search(query, max_results_count = 50)
    search = Search.new(self, query, max_results_count)
    search.results
  end

  def report_count
    count = redis.zcard(set_key)
    puts "Redis sorted set, '#{set_key}', populated with #{count} members."
  end
end

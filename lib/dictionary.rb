# Redis autocomplete example
class Dictionary
  def initialize(set_key)
    @redis = Redis.new
    @set_key = set_key
    @file_name = 'female-names.txt'

    # Populate the redis sorted-set (or refresh if it already exists).
    refresh_index
  end

  def refresh_index
    if @redis.exists(@set_key)
      @redis.del(@set_key)
      puts "Deleted redis key: #{@set_key}. Refreshing now."
    end

    populate_redis_set
  end

  # Search for a name in the list
  # @param prefix [String] your search term
  # @param max_results_count [Integer] maximum results to return
  # @return [Array] search results in lexigraphical order
  def search(prefix, max_results_count = 50)
    results = []
    rangelen = 50 # limit to batches of 50
    start = rank(prefix)
    return [] if start == 0

    while results.length <= max_results_count
      stop = start + rangelen - 1
      range = @redis.zrange(@set_key, start, stop)
      start += rangelen

      break if !range || range.length == 0

      range.each do |entry|
        minlen = [entry.length, prefix.length].min
        slice_of_range = (0...minlen)
        if entry_not_eq_to_prefix?(entry, prefix, slice_of_range)
          max_results_count = results.count
          break
        end
        results << entry[0...-1] if wtf?(entry, prefix, max_results_count)
      end
    end

    results
  end

  def old_refresh_index
    # create the autocompletion sorted set
    if @redis.exists(@set_key)
      puts "NOT loading entries, there is already a #{@set_key} key"
    else
      populate_redis_set
    end
  end

  private

  def entry_not_eq_to_prefix?(entry, prefix, slice_of_range)
    entry[slice_of_range] != prefix[slice_of_range]
  end

  # Not sure how to describe significance of this conditional
  def wtf?(entry, results, max_results_count)
    last_value_is_glob = entry[-1..-1] == '*'
    results_not_eq_max = results.length != max_results_count
    last_value_is_glob && results_not_eq_max
  end

  def rank(prefix)
    @redis.zrank(@set_key, prefix)
  end

  def populate_redis_set
    file = File.new(@file_name)
    file.each_line { |name| each_line(name) }
  end

  def each_line(name)
    name.strip! # remove any whitespace, if any
    range = (1..name.length) # from 2nd character to 2nd-to-last character

    range.each { |index| add_to_set(index, name) }
    append_with_glob_member(name)
  end

  def add_to_set(index, name)
    score = 0
    member = name[0...index]
    @redis.zadd(@set_key, score, member)
  end

  # Also add the entire name with wildcard character, to sorted set
  # so that, 'marc', will also lead to 'marcella', 'marcelina', etc
  def append_with_glob_member(name)
    glob_member = name + '*'
    @redis.zadd(@set_key, 0, glob_member)
  end

  def pre_populate_message
    'Loading entries into Redis DB'
  end

  def post_populate_message
    count = @redis.zcard(@set_key)
    "Redis sorted set, '#{@set_key}', populated with #{count} members."
  end
end

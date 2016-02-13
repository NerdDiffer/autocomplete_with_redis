class Dictionary
  # Search for a term in the dictionary
  class Search
    attr_reader :dictionary, :redis, :set_key, :file_name
    attr_reader :results, :range_len, :query, :max_results_count,
                :early_return_trigger, :start

    def initialize(dictionary, query, max_results_count = 50)
      @dictionary = dictionary
      @redis      = dictionary.redis
      @set_key    = dictionary.set_key
      @file_name  = dictionary.file_name

      @early_return_trigger = :early
      @results    = []
      @range_len  = 50 # limit to batches of 50
      @query      = query
      @max_results_count = max_results_count

      search
    end

    private

    # Search for a name in the list
    # @param query [String] your search term
    # @param max_results_count [Integer] maximum results to return
    # @return [Array] search results in lexigraphical order
    def search
      @start = rank
      return [] if start == 0
      while results.length <= max_results_count
        result = iterate
        break if break?(result)
      end
      results
    end

    def iterate
      stop  = start + range_len - 1
      range = redis.zrange(set_key, start, stop)
      @start += range_len

      return early_return_trigger if return_early_from_iterate?(range)

      range.each do |entry|
        result = process(entry)
        break if break?(result)
      end
    end

    def process(entry)
      min_len = [entry.length, query.length].min
      slice_of_range = (0...min_len)

      if entry_not_eq_to_query?(entry, slice_of_range)
        @max_results_count = results.count
        return early_return_trigger
      end

      append_to_results!(entry) if ok_to_append?(entry)
    end

    def append_to_results!(entry)
      new_entry = entry[(0...-1)]
      @results << new_entry
    end

    def rank
      redis.zrank(set_key, query)
    end

    def break?(result)
      result == early_return_trigger
    end

    def return_early_from_iterate?(range)
      !range || range.length == 0
    end

    def entry_not_eq_to_query?(entry, slice_of_range)
      entry[slice_of_range] != query[slice_of_range]
    end

    def ok_to_append?(entry)
      last_value_is_glob = entry[-1..-1] == '*'
      length_not_eq_max  = results.length != max_results_count
      last_value_is_glob && length_not_eq_max
    end
  end
end

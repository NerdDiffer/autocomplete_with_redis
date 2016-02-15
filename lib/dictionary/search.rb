class Dictionary
  # Search for a term in the dictionary
  class Search
    attr_reader :dictionary, :redis, :set_key
    attr_reader :query, :results, :range_len, :start,
                :max_results_count, :early_return_trigger


    def initialize(dictionary, query, max_results_count = 50)
      @dictionary = dictionary
      @redis      = dictionary.redis
      @set_key    = dictionary.set_key

      @query      = query
      @results    = []
      @range_len  = 50 # limit to batches of 50
      @max_results_count = max_results_count
      @early_return_trigger = :early

      search
    end

    private

    # Search for a name in the list
    # @param query [String] your search term
    # @param max_results_count [Integer] maximum results to return
    # @return [Array] search results in lexigraphical order
    def search
      @start = starting_point
      return [] if start.nil?
      while results.length <= max_results_count
        result = iterate
        break if early_trigger?(result)
      end
      results
    end

    def iterate
      stop  = start + range_len - 1
      batch = redis.zrange(set_key, start, stop)
      @start += range_len

      return early_return_trigger if empty?(batch)

      batch.each do |entry|
        processed_entry = process(entry)
        # Need a way for the #process method to signal to the #search method
        # for an early return.
        return early_return_trigger if early_trigger?(processed_entry)
      end
    end

    def process(entry)
      min_len = [entry.length, query.length].min
      range = (0...min_len)

      if not_matching?(entry, range)
        @max_results_count = results.length
        return early_return_trigger
      end

      append_to_results!(entry) if ok_to_append?(entry)
    end

    def append_to_results!(entry)
      name = entry[(0...-1)]
      @results << name
    end

    def starting_point
      redis.zrank(set_key, query)
    end

    def early_trigger?(result)
      result == early_return_trigger
    end

    def empty?(batch)
      batch.empty?
    end

    def not_matching?(entry, range)
      entry[range] != query[range]
    end

    def ok_to_append?(entry)
      last_value_is_glob = entry[-1..-1] == '*'
      length_not_eq_max  = results.length != max_results_count
      last_value_is_glob && length_not_eq_max
    end
  end
end

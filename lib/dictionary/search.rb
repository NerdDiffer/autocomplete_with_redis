class Dictionary
  # Search for a term in the dictionary
  class Search
    attr_reader :dictionary, :redis, :set_key
    attr_reader :query, :_query, :results, :range_len, :start,
                :max_results_count, :early_return_trigger

    def initialize(dictionary, query, max_results_count = 50)
      @dictionary = dictionary
      @redis      = dictionary.redis
      @set_key    = dictionary.set_key

      @query      = query
      @_query     = query.downcase
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

    def starting_point
      redis.zrank(set_key, _query)
    end

    def early_trigger?(result)
      result == early_return_trigger
    end

    def iterate
      stop  = start + range_len - 1
      batch = redis.zrange(set_key, start, stop)
      @start += range_len

      return early_return_trigger if empty?(batch)

      batch.each do |entry|
        process(entry)
      end
    end

    def empty?(batch)
      batch.empty?
    end

    def process(entry)
      range = prepare_range(entry)
      return if not_matching?(entry, range)
      append!(entry) if append?(entry)
    end

    def prepare_range(entry)
      smaller_of_two = [entry.length, _query.length].min
      (0...smaller_of_two)
    end

    def not_matching?(entry, range)
      entry = entry.downcase
      entry[range] != _query[range]
    end

    def append?(entry)
      last_value_is_glob = entry[-1..-1] == '*'
      length_not_eq_max  = results.length != max_results_count
      last_value_is_glob && length_not_eq_max
    end

    def append!(entry)
      name = entry[(0...-1)]
      @results << name
    end
  end
end

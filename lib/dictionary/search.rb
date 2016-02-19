class Dictionary
  # Search for a term in the dictionary
  class Search
    attr_reader :dictionary, :redis, :set_key
    attr_reader :query, :_query, :results, :range_len, :start, :batch,
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
      while num_results_less_than_max?
        result = iterate
        break if early_trigger?(result)
      end
      results
    end

    def starting_point
      redis.zrank(set_key, _query)
    end

    def num_results_less_than_max?
      results.length <= max_results_count
    end

    def early_trigger?(result)
      result == early_return_trigger
    end

    def iterate
      next_batch!

      return early_return_trigger if empty?(batch)

      batch.each do |entry|
        process(entry)
      end
    end

    def next_batch!
      stop   = start + range_len - 1
      @batch = redis.zrange(set_key, start, stop)
      @start += range_len
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
      last_value_is_glob?(entry) && num_results_not_eq_to_max?
    end

    def last_value_is_glob?(entry)
      entry[-1..-1] == '*'
    end

    def num_results_not_eq_to_max?
      results.length != max_results_count
    end

    def append!(entry)
      name = entry[(0...-1)]
      @results << name
    end
  end
end

class Dictionary
  # Helpers for the #refresh method on a Dictionary object
  module Refresh
    private

    def populate_set
      file = File.new(file_name)
      file.each_line { |name| process_line(name) }
    end

    def process_line(name)
      name.strip!
      range = prepare_range(name)

      range.each { |index| add_to_set!(index, name) }
      append_with_glob_member!(name)
    end

    def prepare_range(name)
      (1..name.length)
    end

    def delete_set_key!
      redis.del(set_key)
    end

    def add_to_set!(index, name)
      score = 0
      member = name[0...index]
      redis.zadd(set_key, score, member)
    end

    # Also add the entire name with wildcard character, to sorted set
    # so that, 'marc', will also lead to 'marcella', 'marcelina', etc
    def append_with_glob_member!(name)
      glob_member = name + '*'
      redis.zadd(set_key, 0, glob_member)
    end
  end
end

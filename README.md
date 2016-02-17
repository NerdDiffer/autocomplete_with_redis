# Autocomplete With Redis

This repo is based off the code in
[this blog post](http://oldblog.antirez.com/post/autocomplete-with-redis.html),
by the creator of Redis, Salvatore Sanfilippo.

## Usage

```ruby
dict = Dictionary.new('foo')
dict.refresh
dict.search('ab')
```

for index, key in ipairs(KEYS) do
  redis.call('sadd', key, ARGV[1])
end

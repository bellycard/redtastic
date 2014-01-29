for index, key in ipairs(KEYS) do
  redis.call('srem', key, ARGV[1])
end

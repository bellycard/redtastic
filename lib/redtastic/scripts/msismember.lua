local result = {}

for index, key in ipairs(KEYS) do
  result[index] = redis.call('sismember', key, ARGV[1])
end

return result

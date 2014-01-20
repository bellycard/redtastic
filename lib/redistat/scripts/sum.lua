local sum = 0

for index, key in ipairs(KEYS) do
  -- For each key, read the value and add it to the total
  local value = tonumber(redis.call('HGET', key, ARGV[1]))
  if value then
    sum = sum + value
  end
end

return sum

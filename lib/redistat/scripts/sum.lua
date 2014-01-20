-- Returns the total sum of the values of each key/index pair passed into KEYS & ARGV

local sum = 0

for index, key in ipairs(KEYS) do
  -- For each key, read the value and add it to the total
  local value = tonumber(redis.call('HGET', key, ARGV[index]))
  if value then
    sum = sum + value
  end
end

return sum

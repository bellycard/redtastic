local result = {}
local sum = 0

for index, key in ipairs(KEYS) do
  -- For each key, add its value to the sum, and to the data points array
  local value = tonumber(redis.call('HGET', key, ARGV[1]))
  if value then
    sum = sum + value
    result[index+1] = value
  else
    result[index+1] = 0
  end
end

-- Position 1 in the result array is reserved for the sum
result[1] = sum

return result

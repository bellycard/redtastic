-- Returns an array of values for each corresponding key/index pair passed into KEYS & ARGV

local result = {}

for index, key in ipairs(KEYS) do
  local value = tonumber(redis.call('HGET', key, ARGV[index]))
  if value then
    result[index] = value
  else
    result[index] = 0
  end
end

return result

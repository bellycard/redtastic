-- SPECIAL: ARGV[1] -> number_of_ids
-- SPECIAL: ARGV[2] -> temp_key

local result = {}
local number_of_ids = tonumber(ARGV[1])
local data_point_index = 2
local count = 1

-- union all of the keys
redis.call('sunionstore', ARGV[2], unpack(KEYS))
-- get the cardinality of the resulting set
result[1] = redis.call('scard', ARGV[2])
-- delete the temp key
redis.call('del', ARGV[1])

-- This loop fills returns the union of all the keys (for any number of ids) for each data point interval
local index = 1
while KEYS[index] do
  local keys = {}
  for i=0,(number_of_ids-1) do
    keys[i+1] = KEYS[index+i]
  end
  redis.call('sunionstore', ARGV[2], unpack(keys))
  result[data_point_index] = redis.call('scard', ARGV[2])
  data_point_index = data_point_index + 1
  index = index + number_of_ids
end

return result

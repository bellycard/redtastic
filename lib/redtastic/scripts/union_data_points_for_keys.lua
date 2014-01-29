-- SPECIAL: ARGV[1] -> number_of_ids
-- SPECIAL: ARGV[2] -> temp_key
-- SPECIAL: All ARGV[n], where n > 2, signify an attribute
-- SPECIAL: last n keys, where n is number of attributes, is keys associated with attributes

local result = {}
local number_of_ids = tonumber(ARGV[1])
local data_point_index = 2
local count = 1
local num_attributes = table.getn(ARGV) - 2
local attribute_keys = {}

-- Remove keys associated with attributes and add them to our own attributes_keys array
for i=1,num_attributes do
  table.insert(attribute_keys, table.remove(KEYS))
end

-- union all of the keys
redis.call('sunionstore', ARGV[2], unpack(KEYS))

-- If attribute are present, we want to get the intersect of the result + any attributes and store in ARGV[2]
if num_attributes > 0 then
  redis.call('sinterstore', ARGV[2], ARGV[2], unpack(attribute_keys))
end

-- get the cardinality of the resulting set
result[1] = redis.call('scard', ARGV[2])

-- This loop returns the union of all the keys (for any number of ids) for each data point interval
local index = 1
while KEYS[index] do
  local keys = {}
  for i=0,(number_of_ids-1) do
    keys[i+1] = KEYS[index+i]
  end
  redis.call('sunionstore', ARGV[2], unpack(keys))

  -- If attributes are present, we want to get the interset of this data points result + any attributes
  if num_attributes > 0 then
    redis.call('sinterstore', ARGV[2], ARGV[2], unpack(attribute_keys))
  end

  result[data_point_index] = redis.call('scard', ARGV[2])
  data_point_index = data_point_index + 1
  index = index + number_of_ids
end

-- delete the temp key
redis.call('del', ARGV[2])

return result

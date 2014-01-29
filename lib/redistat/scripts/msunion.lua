-- SPECIAL: ARGV[1] -> tempkey
-- SPECIAL: All ARGV[n], where n > 1, signify an attribute
-- SPECIAL: last n keys, where n is number of attributes, is keys associated with attributes

local num_attributes = table.getn(ARGV) - 1
local attribute_keys = {}

-- Remove keys associated with attributes and add them to our own attributes_keys array
for i=1,num_attributes do
  table.insert(attribute_keys, table.remove(KEYS))
end

-- union all of the keys
redis.call('sunionstore', ARGV[1], unpack(KEYS))

-- If attributes are present, we want to get the intersect of the result + any attributes and store in ARGV[1]
if num_attributes > 0 then
  table.insert(attribute_keys, ARGV[1])
  redis.call('sinterstore', ARGV[1], unpack(attribute_keys))
end

-- get the cardinality of the resulting set
local count = redis.call('scard', ARGV[1])

-- delete the temp key
redis.call('del', ARGV[1])

return count

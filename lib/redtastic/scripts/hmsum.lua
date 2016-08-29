-- Returns the total sum of the values for each key in KEYS, across multiple ids in ARGV
-- KEYS: [ "key1", "key2" ]
-- ARGV: [1, 2, 3]

-- Example data structures
-- hkeys key1
-- => "1" => "1", "2" => "4"
-- hkeys key2
-- => "2" => "3", "3" => "5"
-- hmget key1 1 2 3
-- => ["1", "4", nil]
-- hmget key2 1 2 3
-- => [nil, "3", "5"]

-- This script will evaluate the above data structure and sum the result of the array values
-- that match the ids in ARGV. i.e. The example above will return 5 + 8 = 13

local sum = 0

for _, key in ipairs(KEYS) do
  local value_array = redis.call('HMGET', key, unpack(ARGV))

  for _, elem in ipairs(value_array) do
    if elem then
      sum = sum + tonumber(elem)
    end
  end
end

return sum

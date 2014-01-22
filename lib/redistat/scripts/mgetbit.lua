local unique_ids_key = ARGV[1]
local unique_id      = ARGV[2]

local result = {}

-- Get the index
local unique_id_index = redis.call('HGET', unique_ids_key, unique_id)
-- If it doesn't exists, return zeros for all the keys
if unique_id_index == false then
  for index, key in ipairs(KEYS) do
    result[index] = 0
  end
else
  for index, key in ipairs(KEYS) do
    result[index] = redis.call('GETBIT', key, unique_id_index)
  end
end

return result

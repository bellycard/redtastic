local unique_ids_key = ARGV[1]
local value          = ARGV[2]
local unique_id      = ARGV[3]

-- See if index of unique id exists
-- If not, set it to = the length of the hash
local unique_id_index = redis.call('HGET', unique_ids_key, unique_id)
if unique_id_index == false then
  unique_id_index = redis.call('HLEN', unique_ids_key)
  redis.call('HSET', unique_ids_key, unique_id, unique_id_index)
end

for index, key in ipairs(KEYS) do
  redis.call('SETBIT', key, unique_id_index, value)
end

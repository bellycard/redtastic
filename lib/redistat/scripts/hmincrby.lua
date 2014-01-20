local id = ARGV[1]
local incrby = ARGV[2]

for index, key in ipairs(KEYS) do
  -- For each key, increment by the passed in value
  redis.call('HINCRBY', key, id, incrby)
end

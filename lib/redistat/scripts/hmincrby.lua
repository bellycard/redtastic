-- Increments each corresponding key/index pair passed into KEYS & ARGV
-- SPECIAL: the first index in ARGV needs to be set to the value to increment by

local incrby = ARGV[1]

for index, key in ipairs(KEYS) do
  -- For each key / id increment by the passed in value
  redis.call('HINCRBY', key, ARGV[index+1], incrby)
end

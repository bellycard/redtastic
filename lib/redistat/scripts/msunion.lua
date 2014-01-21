-- SPECIAL: ARGV[1] -> tempkey

-- union all of the keys
redis.call('sunionstore', ARGV[1], unpack(KEYS))
-- get the cardinality of the resulting set
local count = redis.call('scard', ARGV[1])
-- delete the temp key
redis.call('del', ARGV[1])

return count

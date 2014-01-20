-- Returns total combined sum accross all ids and keys, as well as the combined sum accross all ids for each
-- specified data point interval

local result            = {}
local sum               = 0
local number_of_ids     = tonumber(ARGV[1])
local data_point_index  = 2 -- Initialized to 2 since position 1 in result is reserved for the total sum
local count             = 1 -- Used to track whether we should should move to the next data point

for index, key in ipairs(KEYS) do
  -- Get the value associated with the KEY + INDEX pair
  local value = tonumber(redis.call('HGET', key, ARGV[index+1]))

  -- Initialize the total value for the data point if it hasn't been initialized already
  if result[data_point_index] == nil then
    result[data_point_index] = 0
  end

  if value then
    sum = sum + value
    result[data_point_index] = result[data_point_index] + value
  end

  -- Check if we've accounted for each id for the current data point
  -- If true, then move to the next data point
  if count == number_of_ids then
    count = 1
    data_point_index = data_point_index + 1
  else
    count = count + 1
  end
end

-- Position 1 in the result array is reserved for the sum
result[1] = sum

return result

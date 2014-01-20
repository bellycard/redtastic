require 'redistat'
require 'dotenv'

# Using a mock redis library (such as fakeredis) for testing does not work in this situation, since it does
# not support lua scripts or certain bitmap methods.  Thus, we need to use a real instance of redis for testing.
# So that it does not overwrite any sensitive information on a locally running redis instance, specify the port you
# would like the test instance of redis to run with the variable REDIS_PORT in your .env.test file.
# Remember to boot up a redis instance on this port before running the test suite (ie. $redis-server --port 9123)
Dotenv.load('.env.test')
fail('Specify REDIS_PORT in your .env.test') unless ENV['REDIS_PORT'].present?
redis = Redis.new(host: 'localhost', port: ENV['REDIS_PORT'])

RSpec.configure do |config|
  config.before(:each) do
    Redistat::Connection.redis = redis
    Redis.current.flushdb
  end
end

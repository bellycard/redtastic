require 'spec_helper'

describe Redtastic::Connection do
  before do
    # Reset any connections
    Redtastic::Connection.redis = nil
    Redtastic::Connection.namespace = nil
  end

  describe '#establish_connection' do
    before do
      Redtastic::ScriptManager.stub(:load_scripts)
      redis = Redis.new(host: 'foo', port: 9000)
      Redtastic::Connection.establish_connection(redis, 'bar')
    end

    it 'properly sets the redis connection' do
      expect(Redtastic::Connection.redis.client.host).to eq('foo')
      expect(Redtastic::Connection.redis.client.port).to eq(9000)
    end

    it 'properly sets the namespace' do
      expect(Redtastic::Connection.namespace).to eq('bar')
    end
  end

  context 'when setting options one at a time' do
    before do
      Redtastic::Connection.redis = Redis.new(host: 'foo', port: 1111)
      Redtastic::Connection.namespace = 'bar'
    end

    it 'properly sets the redis connection' do
      expect(Redtastic::Connection.redis.client.host).to eq('foo')
      expect(Redtastic::Connection.redis.client.port).to eq(1111)
    end

    it 'properly sets the namespace' do
      expect(Redtastic::Connection.namespace).to eq('bar')
    end
  end
end

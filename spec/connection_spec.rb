require 'spec_helper'

describe Redistat::Connection do
  before do
    # Reset any connections
    Redistat::Connection.redis = nil
    Redistat::Connection.namespace = nil
  end

  describe '#establish_connection' do
    before do
      Redistat::ScriptManager.stub(:load_scripts)
      redis = Redis.new(host: 'foo', port: 9000)
      Redistat::Connection.establish_connection(redis, 'bar')
    end

    it 'properly sets the redis connection' do
      expect(Redistat::Connection.redis.client.host).to eq('foo')
      expect(Redistat::Connection.redis.client.port).to eq(9000)
    end

    it 'properly sets the namespace' do
      expect(Redistat::Connection.namespace).to eq('bar')
    end
  end

  context 'when setting options one at a time' do
    before do
      Redistat::Connection.redis = Redis.new(host: 'foo', port: 1111)
      Redistat::Connection.namespace = 'bar'
    end

    it 'properly sets the redis connection' do
      expect(Redistat::Connection.redis.client.host).to eq('foo')
      expect(Redistat::Connection.redis.client.port).to eq(1111)
    end

    it 'properly sets the namespace' do
      expect(Redistat::Connection.namespace).to eq('bar')
    end
  end
end

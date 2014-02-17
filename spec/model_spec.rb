require 'spec_helper'

describe Redtastic::Model do

  it 'validates type' do
    expect do
      class InvalidType < Redtastic::Model
        type :foo
      end
    end.to raise_error(RuntimeError, 'foo is not a valid type')
  end

  it 'validates resolution' do
    expect do
      class InvalidResolution < Redtastic::Model
        type :counter
        resolution :foo
      end
    end.to raise_error(RuntimeError, 'foo is not a valid resolution')
  end

  context 'counter' do
    before do
      class Visits < Redtastic::Model
        type :counter
        resolution :days
      end

      class NoResolutions < Redtastic::Model
        type :counter
      end

      @no_resolution_key  = 'app1:no_resolutions:1'
      @day_key            = 'app1:visits:2014-01-05:1'
      @week_key           = 'app1:visits:2014-W1:1'
      @month_key          = 'app1:visits:2014-01:1'
      @year_key           = 'app1:visits:2014:1'
      @id                 = 1001
      @index              = 1
      @timestamp          = '2014-01-05'
    end

    describe '#increment' do
      context 'a model with a daily resolution' do
        before do
          Visits.increment(timestamp: @timestamp, id: @id)
        end

        it 'increments the daily key' do
          expect(Redtastic::Connection.redis.hget(@day_key, @index)).to eq('1')
        end

        it 'increments the weekly key' do
          expect(Redtastic::Connection.redis.hget(@week_key, @index)).to eq('1')
        end

        it 'increments the monthly key' do
          expect(Redtastic::Connection.redis.hget(@month_key, @index)).to eq('1')
        end

        it 'increments the yearly key' do
          expect(Redtastic::Connection.redis.hget(@year_key, @index)).to eq('1')
        end
      end

      context 'when specifying the \'by\' parameter' do
        it 'increments the key by the given amount' do
          Visits.increment(timestamp: @timestamp, id: @id, by: 5)
          expect(Redtastic::Connection.redis.hget(@day_key, @index)).to eq('5')
        end

        it 'allows for negative increments' do
          Visits.increment(timestamp: @timestamp, id: @id, by: -5)
          expect(Redtastic::Connection.redis.hget(@day_key, @index)).to eq('-5')
        end
      end

      context 'a model with no resolution' do
        it 'increments the key' do
          NoResolutions.increment(id: @id)
          expect(Redtastic::Connection.redis.hget(@no_resolution_key, @index)).to eq('1')
        end
      end

      context 'multiple ids' do
        before do
          ids = [1001, 1002, 2003]
          Visits.increment(timestamp: @timestamp, id: ids)
        end

        it 'increments the keys for each id' do
          expect(Redtastic::Connection.redis.hget(@day_key, '1')).to eq('1')
          expect(Redtastic::Connection.redis.hget(@day_key, '2')).to eq('1')
          expect(Redtastic::Connection.redis.hget('app1:visits:2014-01-05:2', '3')).to eq('1')
        end
      end
    end

    describe '#decrement' do
      context 'a model with a resolution' do
        before do
          Redtastic::Connection.redis.hset(@day_key, @index, '1')
          Visits.decrement(timestamp: @timestamp, id: @id)
        end

        it 'decrements the key' do
          expect(Redtastic::Connection.redis.hget(@day_key, @index)).to eq('0')
        end
      end

      context 'when specifying the \'by\' parameter' do
        it 'decrements the key by the given amount' do
          Visits.decrement(timestamp: @timestamp, id: @id, by: 5)
          expect(Redtastic::Connection.redis.hget(@day_key, @index)).to eq('-5')
        end

        it 'allows for negative decrements' do
          Visits.decrement(timestamp: @timestamp, id: @id, by: -5)
          expect(Redtastic::Connection.redis.hget(@day_key, @index)).to eq('5')
        end
      end

      context 'a model with no resolution' do
        before do
          Redtastic::Connection.redis.hset(@no_resolution_key, @index, '1')
          NoResolutions.decrement(id: @id)
        end

        it 'decrements the key' do
          expect(Redtastic::Connection.redis.hget(@no_resolution_key, @index)).to eq('0')
        end
      end

      context 'multiple ids' do
        before do
          ids = [1001, 1002, 2003]
          Visits.decrement(timestamp: @timestamp, id: ids)
        end

        it 'decrements the keys for each id' do
          expect(Redtastic::Connection.redis.hget(@day_key, '1')).to eq('-1')
          expect(Redtastic::Connection.redis.hget(@day_key, '2')).to eq('-1')
          expect(Redtastic::Connection.redis.hget('app1:visits:2014-01-05:2', '3')).to eq('-1')
        end
      end
    end

    describe '#find' do
      context 'a model with a resolution' do
        before do
          Visits.increment(timestamp: @timestamp, id: @id)
          Visits.increment(timestamp: '2014-01-02', id: @id)
        end

        it 'finds the value for a single day' do
          expect(Visits.find(year: 2014, month: 1, day: 5, id: @id)).to eq(1)
        end

        it 'finds the value for a single week' do
          expect(Visits.find(year: 2014, week: 1, id: @id)).to eq(2)
        end

        it 'finds the value for a single month' do
          expect(Visits.find(year: 2014, month: 1, id: @id)).to eq(2)
        end

        it 'finds the value for a single year' do
          expect(Visits.find(year: 2014, id: @id)).to eq(2)
        end
      end

      context 'a model with no resolution' do
        before do
          3.times { NoResolutions.increment(id: @id) }
        end

        it 'finds the value for the counter' do
          expect(NoResolutions.find(id: @id)).to eq(3)
        end
      end

      context 'mutiple ids' do
        before do
          2.times { Visits.increment(timestamp: @timestamp, id: 1001) }
          Visits.increment(timestamp: @timestamp, id: 2003)
        end

        it 'returns an array of the values for each id' do
          expected_result = [2, 1]
          expect(Visits.find(year: 2014, month: 1, day: 5, id: [1001, 2003])).to eq(expected_result)
        end
      end
    end

    describe '#aggregate' do
      context 'when no interval specified' do
        it 'returns the total over the date range' do
          9.times { |day| Redtastic::Connection.redis.hincrby("app1:visits:2014-01-0#{day + 1}:1", '1', 1) }
          res = Visits.aggregate(start_date: '2014-01-01', end_date: '2014-01-09', id: @id)
          expect(res).to eq(9)
        end

        it 'returns the correct total over the date range when resolution is weeks' do
          class Foo < Redtastic::Model
            type :counter
            resolution :weeks
          end
          3.times { |num| Redtastic::Connection.redis.hincrby("app1:foo:2014-W#{num}:1", '1', 1) }
          res = Foo.aggregate(start_date: '2014-01-01', end_date: '2014-01-09', id: @id)
          expect(res).to eq(2)
        end

        it 'returns the correct total over the date range when the resolution is months' do
          class Foo < Redtastic::Model
            type :counter
            resolution :months
          end
          3.times { Redtastic::Connection.redis.hincrby('app1:foo:2014-01:1', '1', 1) }
          res = Foo.aggregate(start_date: '2014-01-01', end_date: '2014-01-09', id: @id)
          expect(res).to eq(3)
        end

        it 'returns the correct total over the date range when resolution is yearly' do
          class Foo < Redtastic::Model
            type :counter
            resolution :years
          end
          3.times { Redtastic::Connection.redis.hincrby('app1:foo:2014:1', '1', 1) }
          res = Foo.aggregate(start_date: '2014-01-01', end_date: '2014-01-09', id: @id)
          expect(res).to eq(3)
        end
      end

      context 'when interval is specified' do
        before do
          @params = { start_date: '2014-01-01', end_date: '2014-01-08', id: @id }
          8.times { |day| Visits.increment(timestamp: "2014-01-0#{day + 1}", id: @id) }
        end

        context 'and is days' do
          before do
            @params[:interval] = :days
            @result = Visits.aggregate(@params)
          end

          it 'returns the total over the date range' do
            expect(@result[:visits]).to eq(8)
          end

          it 'returns the proper amount of data points' do
            expect(@result[:days].size).to eq(8)
          end

          it 'returns the correct data for each point in the interval' do
            @result[:days].each do |day|
              expect(day[:visits]).to eq(1)
            end
          end

          it 'returns the correct dates for each point in the interval' do
            current_date = Date.parse(@params[:start_date])
            @result[:days].each do |day|
              expect(day[:date]).to eq(current_date.strftime('%Y-%m-%d'))
              current_date = current_date.advance(days: +1)
            end
          end
        end

        context 'and is weeks' do
          before do
            @params[:interval] = :weeks
            @result = Visits.aggregate(@params)
          end

          it 'returns the total over the date range' do
            expect(@result[:visits]).to eq(8)
          end

          it 'returns the proper amount of data points' do
            expect(@result[:weeks].size).to eq(2)
          end

          it 'returns the correct data for each point in the interval' do
            expect(@result[:weeks][0][:visits]).to eq(5)
            expect(@result[:weeks][1][:visits]).to eq(3)
          end

          it 'returns the correct dates for each point in the interval' do
            expect(@result[:weeks][0][:date]).to eq('2014-W1')
            expect(@result[:weeks][1][:date]).to eq('2014-W2')
          end
        end

        context 'and is months' do
          before do
            @params[:interval] = :months
            @result = Visits.aggregate(@params)
          end

          it 'returns the total over the date range' do
            expect(@result[:visits]).to eq(8)
          end

          it 'returns the proper amount of data points' do
            expect(@result[:months].size).to eq(1)
          end

          it 'returns the correct data for each point in the interval' do
            expect(@result[:months][0][:visits]).to eq(8)
          end

          it 'returns the correct dates for each point in the interval' do
            expect(@result[:months][0][:date]).to eq('2014-01')
          end
        end

        context 'and is years' do
          before do
            @params[:interval] = :years
            @result = Visits.aggregate(@params)
          end

          it 'returns the total over the date range' do
            expect(@result[:visits]).to eq(8)
          end

          it 'returns the proper amount of data points' do
            expect(@result[:years].size).to eq(1)
          end

          it 'returns the correct data for each point in the interval' do
            expect(@result[:years][0][:visits]).to eq(8)
          end

          it 'returns the correct dates for each point in the interval' do
            expect(@result[:years][0][:date]).to eq('2014')
          end
        end
      end

      context 'mutiple ids' do
        before do
          9.times { |day| Redtastic::Connection.redis.hincrby("app1:visits:2014-01-0#{day + 1}:1", '1', 1) }
          3.times { |day| Redtastic::Connection.redis.hincrby("app1:visits:2014-01-0#{day + 1}:2", '3', 1) }
          @params = { start_date: '2014-01-01', end_date: '2014-01-09', id: [1001, 2003] }
        end

        context 'when no interval is specified' do
          it 'returns the aggregate total for both ids combined' do
            result = Visits.aggregate(@params)
            expect(result).to eq(12)
          end
        end

        context 'when an interval is specified' do
          before do
            @result = Visits.aggregate(@params.merge!(interval: :days))
          end

          it 'returns the total over the date range' do
            expect(@result[:visits]).to eq(12)
          end

          it 'returns the proper amount of data points' do
            expect(@result[:days].size).to eq(9)
          end

          it 'returns the correct data for each point in the interval' do
            3.times do |num|
              expect(@result[:days][num][:visits]).to eq(2)
            end
            (3..8).each do |num|
              expect(@result[:days][num][:visits]).to eq(1)
            end
          end
        end
      end
    end
  end

  context 'unique counter' do
    before do
      class Customers < Redtastic::Model
        type :unique
        resolution :days
      end
      @id                 = 1001
      @timestamp          = '2014-01-05'
      @user1              = 4321
      @user2              = 8765
      @day_key            = 'app1:customers:2014-01-05:1001'
      @week_key           = 'app1:customers:2014-W1:1001'
      @month_key          = 'app1:customers:2014-01:1001'
      @year_key           = 'app1:customers:2014:1001'
    end

    describe '#increment' do
      context 'single ids' do
        before do
          Customers.increment(id: @id, timestamp: @timestamp, unique_id: @user1)
          Customers.increment(id: @id, timestamp: @timestamp, unique_id: @user2)
        end

        it 'adds user 1 to the set' do
          expect(Redtastic::Connection.redis.sismember(@day_key, @user1)).to be true
        end

        it 'adds user 2 to the set' do
          expect(Redtastic::Connection.redis.sismember(@day_key, @user2)).to be true
        end

        it 'adds user 1 to the weekly set' do
          expect(Redtastic::Connection.redis.sismember(@week_key, @user1)).to be true
        end

        it 'adds user 1 to the monthly set' do
          expect(Redtastic::Connection.redis.sismember(@month_key, @user1)).to be true
        end

        it 'adds user 1 to the yearly set' do
          expect(Redtastic::Connection.redis.sismember(@year_key, @user1)).to be true
        end
      end

      context 'multiple ids' do
        before do
          ids = [1001, 1002]
          Customers.increment(id: ids, timestamp: @timestamp, unique_id: @user1)
        end

        it 'increments bits on both keys' do
          expect(Redtastic::Connection.redis.sismember(@day_key, @user1)).to be true
          expect(Redtastic::Connection.redis.sismember('app1:customers:2014-01-05:1002', @user1)).to be true
        end
      end
    end

    describe '#decrement' do
      before do
        # First add user 1
        Redtastic::Connection.redis.sadd(@day_key, @user1)
      end

      it 'decrements user1 removing it from the set' do
        # Make sure it was properly added first
        expect(Redtastic::Connection.redis.sismember(@day_key, @user1)).to be true
        Customers.decrement(id: @id, timestamp: @timestamp, unique_id: @user1)
        expect(Redtastic::Connection.redis.sismember(@day_key, @user1)).to be false
      end
    end

    describe '#find' do
      context 'single ids' do
        before do
          Customers.increment(id: @id, timestamp: @timestamp, unique_id: @user1)
        end

        it 'finds the value for a unique id on a single day' do
          expect(Customers.find(id: @id, year: 2014, month: 1, day: 5, unique_id: @user1)).to eq(1)
          expect(Customers.find(id: @id, year: 2014, month: 1, day: 5, unique_id: 1)).to eq(0)
        end

        it 'finds the value for a unique id in a single week' do
          expect(Customers.find(id: @id, year: 2014, week: 1, unique_id: @user1)).to eq(1)
          expect(Customers.find(id: @id, year: 2014, week: 1, unique_id: 1)).to eq(0)
        end

        it 'finds the value for a unique id in a single month' do
          expect(Customers.find(id: @id, year: 2014, month: 1, unique_id: @user1)).to eq(1)
          expect(Customers.find(id: @id, year: 2014, month: 1, unique_id: 1)).to eq(0)
        end

        it 'finds the value for a unique id in a single year' do
          expect(Customers.find(id: @id, year: 2014, unique_id: @user1)).to eq(1)
          expect(Customers.find(id: @id, year: 2014, unique_id: 1)).to eq(0)
        end
      end

      context 'mutiple ids' do
        before do
          2.times { Customers.increment(id: 1001, timestamp: @timestamp, unique_id: @user1) }
          Customers.increment(id: 1002, timestamp: @timestamp, unique_id: @user1)
        end

        it 'returns an array of the values for each id' do
          expected_result = [1, 1, 0]
          params = { id: [1001, 1002, 1003], year: 2014, month: 1, day: 5, unique_id: @user1 }
          expect(Customers.find(params)).to eq(expected_result)
        end
      end
    end

    describe '#aggregate' do
      context 'when no interval is specified' do
        it 'returns the total over the date range' do
          9.times { |day| Redtastic::Connection.redis.sadd("app1:customers:2014-01-0#{day + 1}:#{@id}", @user1) }
          3.times { |day| Redtastic::Connection.redis.sadd("app1:customers:2014-01-0#{day + 1}:#{@id}", @user2) }
          result = Customers.aggregate(start_date: '2014-01-01', end_date: '2014-01-09', id: @id)
          expect(result).to eq(2)
        end

        it 'returns the correct total over the date range when the resolution is weeks' do
          class Foo < Redtastic::Model
            type :unique
            resolution :weeks
          end
          3.times { |num| Redtastic::Connection.redis.sadd("app1:foo:2014-W#{num}:#{@id}", @user1) }
          2.times { |num| Redtastic::Connection.redis.sadd("app1:foo:2014-W#{num}:#{@id}", @user2) }
          result = Foo.aggregate(start_date: '2014-01-01', end_date: '2014-01-09', id: @id)
          expect(result).to eq(2)
        end

        it 'returns the correct total over the date range when the resolution is months' do
          class Foo < Redtastic::Model
            type :unique
            resolution :months
          end
          3.times { |num| Redtastic::Connection.redis.sadd("app1:foo:2014-01:#{@id}", @user1) }
          2.times { |num| Redtastic::Connection.redis.sadd("app1:foo:2014-01:#{@id}", @user2) }
          result = Foo.aggregate(start_date: '2014-01-01', end_date: '2014-01-09', id: @id)
          expect(result).to eq(2)
        end

        it 'returns the correct total over the date range when the resolution is years' do
          class Foo < Redtastic::Model
            type :unique
            resolution :years
          end
          3.times { |num| Redtastic::Connection.redis.sadd("app1:foo:2014:#{@id}", @user1) }
          2.times { |num| Redtastic::Connection.redis.sadd("app1:foo:2014:#{@id}", @user2) }
          result = Foo.aggregate(start_date: '2014-01-01', end_date: '2014-01-09', id: @id)
          expect(result).to eq(2)
        end
      end

      context 'when interval is specified' do
        before do
          @params = { start_date: '2014-01-01', end_date: '2014-01-09', id: @id }
          9.times { |day| Customers.increment(id: @id, timestamp: "2014-01-0#{day + 1}", unique_id: @user1) }
          3.times { |day| Customers.increment(id: @id, timestamp: "2014-01-0#{day + 1}", unique_id: @user2) }
        end

        context 'and is days' do
          before do
            @params[:interval] = :days
            @result = Customers.aggregate(@params)
          end

          it 'returns the total over the date range' do
            expect(@result[:customers]).to eq(2)
          end

          it 'returns the proper amount of data points' do
            expect(@result[:days].size).to eq(9)
          end

          it 'returns the correct data for each point in the interval' do
            3.times { |num| expect(@result[:days][num][:customers]).to eq(2) }
            6.times { |num| expect(@result[:days][num + 3][:customers]).to eq(1) }
          end

          it 'returns the correct dates for each point in the interval' do
            current_date = Date.parse(@params[:start_date])
            @result[:days].each do |day|
              expect(day[:date]).to eq(current_date.strftime('%Y-%m-%d'))
              current_date = current_date.advance(days: +1)
            end
          end
        end

        context 'and is weeks' do
          before do
            @params[:interval] = :weeks
            @result = Customers.aggregate(@params)
          end

          it 'returns the total over the date range' do
            expect(@result[:customers]).to eq(2)
          end

          it 'returns the proper amount of data points' do
            expect(@result[:weeks].size).to eq(2)
          end

          it 'returns the correct data for each point in the interval' do
            expect(@result[:weeks][0][:customers]).to eq(2)
            expect(@result[:weeks][1][:customers]).to eq(1)
          end

          it 'returns the correct dates for each point in the interval' do
            expect(@result[:weeks][0][:date]).to eq('2014-W1')
            expect(@result[:weeks][1][:date]).to eq('2014-W2')
          end
        end

        context 'and is years' do
          before do
            @params[:interval] = :years
            @result = Customers.aggregate(@params)
          end

          it 'returns the total over the date range' do
            expect(@result[:customers]).to eq(2)
          end

          it 'returns the proper amount of data points' do
            expect(@result[:years].size).to eq(1)
          end

          it 'returns the correct data for each point in the interval' do
            expect(@result[:years][0][:customers]).to eq(2)
          end

          it 'returns the correct dates for each point in the interval' do
            expect(@result[:years][0][:date]).to eq('2014')
          end
        end
      end

      context 'multiple ids' do
        before do
          9.times do |day|
            Customers.increment(id: 1001, timestamp: "2014-01-0#{day + 1}", unique_id: @user1)
            Customers.increment(id: 1002, timestamp: "2014-01-0#{day + 1}", unique_id: @user1)
          end
          3.times { |day| Customers.increment(id: 1001, timestamp: "2014-01-0#{day + 1}", unique_id: @user2) }
          @params = { start_date: '2014-01-01', end_date: '2014-01-09', id: [1001, 2003] }
        end

        context 'when no interval is specified' do
          it 'returns the aggregate total for both ids combined' do
            result = Customers.aggregate(@params)
            expect(result).to eq(2)
          end
        end

        context 'when an interval is specified' do
          before do
            @result = Customers.aggregate(@params.merge!(interval: :days))
          end

          it 'returns the total over the date range' do
            expect(@result[:customers]).to eq(2)
          end

          it 'returns the proper amount of data points' do
            expect(@result[:days].size).to eq(9)
          end

          it 'returns the correct data for each point in the interval' do
            3.times { |num| expect(@result[:days][num][:customers]).to eq(2) }
            (3..8).each { |num| expect(@result[:days][num][:customers]).to eq(1) }
          end
        end
      end
    end
  end

  context 'attributes' do
    before do
      class Customers < Redtastic::Model
        type        :unique
        resolution  :days
      end
      class Males < Redtastic::Model
        type :unique
      end
      class Mobile < Redtastic::Model
        type :unique
      end
      @user1         = 1111
      @user2         = 2222
      @user3         = 3333
      @attribute_key = 'app1:males'
    end

    describe '#increment' do
      before do
        Males.increment(unique_id: @user1)
        Males.increment(unique_id: @user2)
      end

      it 'adds user1 to the set' do
        result = Redtastic::Connection.redis.sismember(@attribute_key, @user1)
        expect(result).to be true
      end

      it 'adds user2 to the set' do
        result = Redtastic::Connection.redis.sismember(@attribute_key, @user2)
        expect(result).to be true
      end
    end

    describe '#decrement' do
      before do
        Males.increment(unique_id: @user1)
      end

      it 'adds user1 to the set' do
        Males.decrement(unique_id: @user1)
        result = Redtastic::Connection.redis.sismember(@attribute_key, @user1)
        expect(result).to be false
      end
    end

    describe '#find' do
      before do
        Males.increment(unique_id: @user1)
      end

      it 'returns 1 for a unique_id that is in the attribute set' do
        expect(Males.find(unique_id: @user1)).to eq(1)
      end

      it 'returns 0 for a unique_id that is not in the attribute set' do
        expect(Males.find(unique_id: @user2)).to eq(0)
      end
    end

    describe '#aggregate' do
      before do
        Males.increment(unique_id: @user1)
        Males.increment(unique_id: @user2)
        Mobile.increment(unique_id: @user2)
        9.times{ |day| Redtastic::Connection.redis.sadd("app1:customers:2014-01-0#{day + 1}:#{2222}", @user1) }
        3.times{ |day| Redtastic::Connection.redis.sadd("app1:customers:2014-01-0#{day + 1}:#{1111}", @user2) }
        3.times{ |day| Redtastic::Connection.redis.sadd("app1:customers:2014-01-0#{day + 1}:#{1111}", @user3) }
        @params = { id: [1111, 2222], start_date: '2014-01-01', end_date: '2014-01-09' }
        @attributes = []
      end

      context 'when no interval is specified' do
        context 'and single attribute is specified' do
          it 'returns the total over the date range' do
            @attributes << :males
            result = Customers.aggregate(@params.merge!(attributes: @attributes))
            expect(result).to eq(2)
          end

          it 'does not require use of an array if specifying only one attribute' do
            result = Customers.aggregate(@params.merge!(attributes: :males))
            expect(result).to eq(2)
          end
        end

        context 'and multiple attributes are specified' do
          it 'returns the total over the date range' do
            @attributes << :males
            @attributes << :mobile
            result = Customers.aggregate(@params.merge!(attributes: @attributes))
            expect(result).to eq(1)
          end
        end
      end

      context 'when interval is specified' do
        context 'and single attribute is specified' do
          before do
            @attributes << :males
            @result = Customers.aggregate(@params.merge!(attributes: @attributes, interval: :days))
          end

          it 'returns the total over the date range' do
            expect(@result[:customers]).to eq(2)
          end

          it 'returns the proper amount of data points' do
            expect(@result[:days].size).to eq(9)
          end

          it 'returns the correct data for each point in the interval' do
            3.times { |num| expect(@result[:days][num][:customers]).to eq(2) }
            6.times { |num| expect(@result[:days][num + 3][:customers]).to eq(1) }
          end
        end

        context 'and multiple attributes are specified' do
          before do
            @attributes << :males
            @attributes << :mobile
            @result = Customers.aggregate(@params.merge!(attributes: @attributes, interval: :days))
          end

          it 'returns the total over the date range' do
            expect(@result[:customers]).to eq(1)
          end

          it 'returns the proper amount of data points' do
            expect(@result[:days].size).to eq(9)
          end

          it 'returns the correct data for each point in the interval' do
            3.times { |num| expect(@result[:days][num][:customers]).to eq(1) }
            6.times { |num| expect(@result[:days][num + 3][:customers]).to eq(0) }
          end
        end
      end
    end
  end
end

require 'spec_helper'

describe Redistat::Model do

  it 'validates type' do
    expect do
      class InvalidType < Redistat::Model
        type :foo
      end
    end.to raise_error(RuntimeError, 'foo is not a valid type')
  end

  it 'validates resolution' do
    expect do
      class InvalidResolution < Redistat::Model
        type :counter
        resolution :foo
      end
    end.to raise_error(RuntimeError, 'foo is not a valid resolution')
  end

  context 'counter' do
    before do
      class Visits < Redistat::Model
        type :counter
        resolution :days
      end

      class NoResolutions < Redistat::Model
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
          expect(Redistat::Connection.redis.hget(@day_key, @index)).to eq('1')
        end

        it 'increments the weekly key' do
          expect(Redistat::Connection.redis.hget(@week_key, @index)).to eq('1')
        end

        it 'increments the monthly key' do
          expect(Redistat::Connection.redis.hget(@month_key, @index)).to eq('1')
        end

        it 'increments the yearly key' do
          expect(Redistat::Connection.redis.hget(@year_key, @index)).to eq('1')
        end
      end

      context 'a model with no resolution' do
        it 'increments the key' do
          NoResolutions.increment(id: @id)
          expect(Redistat::Connection.redis.hget(@no_resolution_key, @index)).to eq('1')
        end
      end

      context 'multiple ids' do
        before do
          ids = [1001, 1002, 2003]
          Visits.increment(timestamp: @timestamp, id: ids)
        end

        it 'increments the keys for each id' do
          expect(Redistat::Connection.redis.hget(@day_key, '1')).to eq('1')
          expect(Redistat::Connection.redis.hget(@day_key, '2')).to eq('1')
          expect(Redistat::Connection.redis.hget('app1:visits:2014-01-05:2', '3')).to eq('1')
        end
      end
    end

    describe '#decrement' do
      before do
        Redistat::Connection.redis.hset(@day_key, @index, '1')
        Visits.decrement(timestamp: @timestamp, id: @id)
      end

      context 'a model with a resolution' do
        it 'decrements the key' do
          expect(Redistat::Connection.redis.hget(@day_key, @index)).to eq('0')
        end
      end

      context 'a model with no resolution' do
        before do
          Redistat::Connection.redis.hset(@no_resolution_key, @index, '1')
          NoResolutions.decrement(id: @id)
        end

        it 'decrements the key' do
          expect(Redistat::Connection.redis.hget(@no_resolution_key, @index)).to eq('0')
        end
      end

      context 'multiple ids' do
        before do
          ids = [1001, 1002, 2003]
          Visits.decrement(timestamp: @timestamp, id: ids)
        end

        it 'decrements the keys for each id' do
          expect(Redistat::Connection.redis.hget(@day_key, '1')).to eq('-1')
          expect(Redistat::Connection.redis.hget(@day_key, '2')).to eq('-1')
          expect(Redistat::Connection.redis.hget('app1:visits:2014-01-05:2', '3')).to eq('-1')
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
          9.times { |day| Redistat::Connection.redis.hincrby("app1:visits:2014-01-0#{day + 1}:1", '1', 1) }
          res = Visits.aggregate(start_date: '2014-01-01', end_date: '2014-01-09', id: @id)
          expect(res).to eq(9)
        end

        it 'returns the correct total over the date range when resolution is weeks' do
          class Foo < Redistat::Model
            type :counter
            resolution :weeks
          end
          3.times { |num| Redistat::Connection.redis.hincrby("app1:foo:2014-W#{num}:1", '1', 1) }
          res = Foo.aggregate(start_date: '2014-01-01', end_date: '2014-01-09', id: @id)
          expect(res).to eq(2)
        end

        it 'returns the correct total over the date range when the resolution is months' do
          class Foo < Redistat::Model
            type :counter
            resolution :months
          end
          3.times { Redistat::Connection.redis.hincrby('app1:foo:2014-01:1', '1', 1) }
          res = Foo.aggregate(start_date: '2014-01-01', end_date: '2014-01-09', id: @id)
          expect(res).to eq(3)
        end

        it 'returns the correct total over the date range when resolution is yearly' do
          class Foo < Redistat::Model
            type :counter
            resolution :years
          end
          3.times { Redistat::Connection.redis.hincrby('app1:foo:2014:1', '1', 1) }
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
          9.times { |day| Redistat::Connection.redis.hincrby("app1:visits:2014-01-0#{day + 1}:1", '1', 1) }
          3.times { |day| Redistat::Connection.redis.hincrby("app1:visits:2014-01-0#{day + 1}:2", '3', 1) }
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
      class Customers < Redistat::Model
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

        it 'increments user1 by setting the bit at index 0 to 1' do
          expect(Redistat::Connection.redis.getbit(@day_key, 0)).to eq(1)
        end

        it 'increments user2 by setting the bit at index 1 to 1' do
          expect(Redistat::Connection.redis.getbit(@day_key, 1)).to eq(1)
        end

        it 'increments the bit on the week key' do
          expect(Redistat::Connection.redis.getbit(@week_key, 0)).to eq(1)
        end

        it 'increments the bit on the month key' do
          expect(Redistat::Connection.redis.getbit(@month_key, 0)).to eq(1)
        end

        it 'increments the bit on the year key' do
          expect(Redistat::Connection.redis.getbit(@year_key, 0)).to eq(1)
        end
      end

      context 'multiple ids' do
        before do
          ids = [1001, 1002]
          Customers.increment(id: ids, timestamp: @timestamp, unique_id: @user1)
        end

        it 'increments bits on both keys' do
          expect(Redistat::Connection.redis.getbit(@day_key, 0)).to eq(1)
          expect(Redistat::Connection.redis.getbit('app1:customers:2014-01-05:1002', 0)).to eq(1)
        end
      end
    end

    describe '#decrement' do
      before do
        # First set the bit to 1
        Redistat::Connection.redis.setbit(@day_key, 0, 1)
      end

      it 'decrements user1 by setting the bit at index 0 to 0' do
        # Make sure it was properly set to 1 first
        expect(Redistat::Connection.redis.getbit(@day_key, 0)).to eq(1)
        Customers.decrement(id: @id, timestamp: @timestamp, unique_id: @user1)
        expect(Redistat::Connection.redis.getbit(@day_key, 0)).to eq(0)
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
    end
  end
end

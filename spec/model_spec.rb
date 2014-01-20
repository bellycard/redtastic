require 'spec_helper'

describe Redistat::Model do
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
    end
  end
end

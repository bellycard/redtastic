module Redistat
  class Model
    class << self
      # Recording

      def increment(params)
        increment_counter(params, 1)
      end

      def decrement(params)
        increment_counter(params, -1)
      end

      # Retrieving

      def find(params)
        timestamp = ''
        timestamp += "#{params[:year]}"
        timestamp += "-#{zeros(params[:month])}" if params[:month].present?
        timestamp += "-W#{params[:week]}"        if params[:week].present?
        timestamp += "-#{zeros(params[:day])}"   if params[:day].present?
        params.merge!(timestamp: timestamp)
        Redistat::Connection.redis.hget(key(params), index(params[:id])).to_i
      end

      def aggregate(params)
        argv      = []
        key_data  = fill_keys_and_dates(params)
        keys      = key_data[0]
        argv      << index(params[:id])

        # If interval is present, we return a hash including the total as well as a data point for each interval.
        # Example: Visits.aggregate(start_date: 2014-01-05, end_date: 2013-01-06, id: 1, interval: :days)
        # {
        #    visits: 2
        #    days: [
        #      {
        #        created_at: 2014-01-05,
        #        visits: 1
        #      },
        #      {
        #        created_at: 2014-01-06,
        #        visits: 1
        #      }
        #    ]
        # }
        if params[:interval].present? && @_resolution.present?
          result       = HashWithIndifferentAccess.new
          dates        = key_data[1]
          data_points  = Redistat::ScriptManager.data_points_for_keys(keys, argv)

          # The data_points_for_keys lua script returns an array of all the data points, with one exception:
          # the value at index 0 is the total across all the data points, so we pop it off of the data points array.
          result[model_name]         = data_points.shift
          result[params[:interval]]  = []

          data_points.each_with_index do |data_point, index|
            point_hash                 = HashWithIndifferentAccess.new
            point_hash[model_name]     = data_point
            point_hash[:date]          = dates[index]
            result[params[:interval]]  << point_hash
          end
          result
        else
          # If interval is not present, we just return the total as an integer
          Redistat::ScriptManager.sum(keys, argv)
        end
      end

      private

        def type(type_name)
          types = [:counter, :unique, :mosaic]
          fail "#{type_name} is not a valid type" unless types.include?(type_name)
          @_type = type_name
        end

        def resolution(resolution_name)
          resolutions = [:days, :weeks, :months, :years]
          fail "#{resolution_name} is not a valid resolution" unless resolutions.include?(resolution_name)
          @_resolution = resolution_name
        end

        def increment_counter(params, value)
          keys = []
          argv = []
          if params[:timestamp].present?
            keys << key(params, :days)   unless [:weeks, :months, :years].include?(@_resolution)
            keys << key(params, :weeks)  unless [:months, :years].include?(@_resolution)
            keys << key(params, :months) unless @_resolution == :years
            keys << key(params, :years)
          else
            keys << key(params)
          end
          argv << index(params[:id])
          argv << value
          Redistat::ScriptManager.hmincrby(keys, argv)
        end

        def fill_keys_and_dates(params)
          keys  = []
          dates = []
          start_date = Date.parse(params[:start_date]) if params[:start_date].is_a?(String)
          end_date   = Date.parse(params[:end_date])   if params[:end_date].is_a?(String)
          if params[:interval].present?
            interval = params[:interval]
          else
            interval = @_resolution
          end
          current_date = start_date
          while current_date <= end_date
            params[:timestamp] = current_date
            dates << formatted_timestamp(current_date, interval)
            # TODO: handle multiple ids here
            # Loop through ids
            if params[:id].is_a?(Array)
              ids = params[:id]
              ids.each do |id|
                params[:id] = id
                keys << key(params, interval)
              end
            else
              keys << key(params, interval)
            end
            current_date = current_date.advance(interval => +1)
          end
          [keys, dates]
        end

        def key(params, interval = nil)
          key = ''
          key += "#{Redistat::Connection.namespace}:" if Redistat::Connection.namespace.present?
          key += "#{model_name}:"
          if params[:timestamp].present?
            timestamp = params[:timestamp]
            timestamp = formatted_timestamp(params[:timestamp], interval) if interval.present?
            key += "#{timestamp}:"
          end
          key + "#{bucket(params[:id])}"
        end

        def formatted_timestamp(timestamp, interval)
          timestamp = Date.parse(timestamp) if timestamp.is_a?(String)
          case interval
          when :days
            timestamp.strftime('%Y-%m-%d')
          when :weeks
            week_number = timestamp.cweek
            result = timestamp.strftime('%Y')
            result + "-W#{week_number}"
          when :months
            timestamp.strftime('%Y-%m')
          when :years
            timestamp.strftime('%Y')
          end
        end

        def bucket(id)
          @_type == :counter ? id / 1000 : id
        end

        def index(id)
          id % 1000
        end

        def zeros(number)
          "0#{number}" if number < 10
        end

        def model_name
          name.underscore
        end
    end
  end
end

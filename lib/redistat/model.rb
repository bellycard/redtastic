module Redistat
  class Model
    class << self
      # Recording

      def increment(params)
        key_data = fill_keys_for_update(params)
        if @_type == :unique
          adjust_unique_counter(params, key_data[0], 1)
        else
          Redistat::ScriptManager.hmincrby(key_data[0], key_data[1].unshift(1))
        end
      end

      def decrement(params)
        key_data = fill_keys_for_update(params)
        if @_type == :unique
          adjust_unique_counter(params, key_data[0], 0)
        else
          Redistat::ScriptManager.hmincrby(key_data[0], key_data[1].unshift(-1))
        end
      end

      # Retrieving

      def find(params)
        keys = []
        argv = []

        # Construct the key's timestamp from inputed date parameters
        timestamp = ''
        timestamp += "#{params[:year]}"
        timestamp += "-#{zeros(params[:month])}" if params[:month].present?
        timestamp += "-W#{params[:week]}"        if params[:week].present?
        timestamp += "-#{zeros(params[:day])}"   if params[:day].present?
        params.merge!(timestamp: timestamp)

        # Handle multiple ids
        ids = id_param_to_array(params[:id])

        ids.each do |id|
          params[:id] = id
          keys << key(params)
          argv << index(id)
        end

        if @_type == :unique
          argv = []
          argv << unique_ids_key
          argv << params[:unique_id]
          result = Redistat::ScriptManager.mgetbit(keys, argv)
        else
          result = Redistat::ScriptManager.hmfind(keys, argv)
        end

        # If only for a single id, just return the value rather than an array
        if result.size == 1
          result[0]
        else
          result
        end
      end

      def aggregate(params)
        key_data  = fill_keys_and_dates(params)
        keys      = key_data[0]
        argv      = key_data[1]

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
          dates        = key_data[2]
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
          argv.shift # Remove the number of ids from the argv array (don't need it in the sum method)
          Redistat::ScriptManager.sum(keys, argv).to_i
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

        def fill_keys_for_update(params)
          keys = []
          argv = []

          # Handle multiple keys
          ids = id_param_to_array(params[:id])

          ids.each do |id|
            params[:id] = id
            if params[:timestamp].present?
              # This is for an update, so we want to build a key for each resolution that is applicable to the model
              scoped_resolutions.each do |resolution|
                keys << key(params, resolution)
                argv << index(id)
              end
            else
              keys << key(params)
              argv << index(id)
            end
          end
          [keys, argv]
        end

        def fill_keys_and_dates(params)
          keys  = []
          dates = []
          argv  = []
          ids   = id_param_to_array(params[:id])

          argv << ids.size
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
            ids.each do |id|
              params[:id] = id
              keys << key(params, interval)
              argv << index(id)
            end
            current_date = current_date.advance(interval => +1)
          end
          [keys, argv, dates]
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
          if @_type == :counter
            key + "#{bucket(params[:id])}"
          else
            key + "#{params[:id]}"
          end
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

        def scoped_resolutions
          case @_resolution
          when :days
            [:days, :weeks, :months, :years]
          when :weeks
            [:weeks, :months, :years]
          when :months
            [:months, :years]
          when :years
            [:years]
          else
            []
          end
        end

        def id_param_to_array(param_id)
          ids = []
          param_id.is_a?(Array) ? ids = param_id : ids << param_id
        end

        def unique_ids_key
          key = ''
          key += "#{Redistat::Connection.namespace}:" if Redistat::Connection.namespace.present?
          key += "#{model_name}:"
          key + 'unique_ids'
        end

        def adjust_unique_counter(params, keys, value)
          args = []
          args << unique_ids_key
          args << value
          args << params[:unique_id]
          Redistat::ScriptManager.msetbit(keys, args)
        end
    end
  end
end

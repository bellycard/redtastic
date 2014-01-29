module Redtastic
  class ScriptManager
    class << self
      def load_scripts(script_path)
        @stored_methods = HashWithIndifferentAccess.new unless @stored_methods.is_a?(Hash)
        Dir["#{script_path}/*.lua"].map do |file|
          method = File.basename(file, '.*')
          unless @stored_methods.key?(method)
            @stored_methods[method] = Redtastic::Connection.redis.script(:load, `cat #{file}`)
          end
        end
      end

      def method_missing(method_name, *args)
        if @stored_methods.is_a?(Hash) && @stored_methods.key?(method_name)
          Redtastic::Connection.redis.evalsha(@stored_methods[method_name], *args)
        else
          fail("Could not find script: #{method_name}.lua")
        end
      end

      def flush_scripts
        @stored_methods = nil
        Redtastic::Connection.redis.script(:flush)
      end

      def to_ary
        nil
      end
    end
  end
end

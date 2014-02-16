module Redtastic
  class Connection
    class << self
      attr_accessor :namespace
      attr_accessor :redis

      def establish_connection(connection, namespace = nil)
        @redis      = connection
        @namespace  = namespace
        Redtastic::ScriptManager.load_scripts(File.join(File.dirname(__FILE__),'/scripts'))
      end
    end
  end
end

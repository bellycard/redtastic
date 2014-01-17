module Redistat
  class Connection
    class << self
      attr_accessor :namespace
      attr_accessor :redis

      def establish_connection(connection, namespace = nil)
        @redis      = connection
        @namespace  = namespace
        Redistat::ScriptManager.load_scripts('./lib/redistat/scripts')
      end
    end
  end
end

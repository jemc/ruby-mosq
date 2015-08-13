
module Mosq
  module FFI
    
    class Error < RuntimeError
      def initialize(message=nil)
        @message = message
      end
      
      def message
        if @message && status_message; "#{status_message} - #{@message}"
        elsif @message;                @message
        elsif status_message;          status_message
        else;                          ""
        end
      end
      
      def status_message
        nil
      end
      
      def self.lookup status
        if status == :errno
          @errno_lookup_table.fetch(::FFI.errno)
        else
          @lookup_table.fetch(status)
        end
      end
      
      @errno_lookup_table = {}
      
      # Populate the errno_lookup_table
      Errno.constants.each do |name|
        kls = Errno.const_get(name)
        begin
          errno = kls.const_get(:Errno)
          @errno_lookup_table[errno] = kls
        rescue NoMethodError, NameError
        end
      end
      
      @lookup_table = {}
      
      # Populate the FFI::Status lookup_table
      (FFI::Status.symbols - [:errno]).each do |status|
        message = FFI.mosquitto_strerror(status)
        message.gsub!(/\.\s*\Z/, '')
        kls = Class.new(Error) { define_method(:status_message) { message } }
        @lookup_table[status] = kls
        const_set Util.const_name(status), kls
      end
      
      # Custom static class to use for timeouts
      Timeout = Class.new(Error) { define_method(:status_message) { "timed out" } }
    end
    
  end
end

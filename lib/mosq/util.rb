
module Mosq
  
  # Helper functions for this library.
  # @api private
  module Util
    module_function
    
    def const_name(lowercase_name)
      lowercase_name.to_s.gsub(/((?:\A\w)|(?:_\w))/) { |x| x[-1].upcase }
    end
    
    def error_check(action, status)
      return if status == :success
      raise Mosq::FFI::Error.lookup(status), "while #{action}"
    end
    
    def null_check(action, obj)
      return unless obj.nil?
      raise Mosq::FFI::Error, "while #{action} - got unexpected null"
    end
    
    def mem_ptr(size, count: 1, clear: true, release: true)
      ptr = ::FFI::MemoryPointer.new(size, count, clear)
      ptr.autorelease = false unless release
      ptr
    end
    
    def strdup_ptr(str, **kwargs)
      str = str + "\x00"
      ptr = mem_ptr(str.bytesize, **kwargs)
      ptr.write_string(str)
      ptr
    end
    
    def strdup_ary_ptr(ary, **kwargs)
      ptr = mem_ptr(:pointer, count: ary.size)
      ary.each_with_index do |str, i|
        cursor = (ptr + i * ::FFI::TypeDefs[:pointer].size)
        cursor.write_pointer(strdup_ptr(str, **kwargs))
      end
      ptr
    end
    
    def connection_info(uri=nil, **overrides)
      info = {
        ssl:  false,
        host: "localhost",
        port: 1883,
      }
      if uri
        # TODO: support IPv6
        pattern = %r{\A(?<schema>mqtts?)://((?<username>[^:@]+)(:(?<password>[^@]+))?@)?(?<host>[^:]+)(:(?<port>\d+))?\Z}
        match = pattern.match(uri)
        if match
          info[:ssl]  = ("mqtts" == match[:schema])
          info[:host] = match[:host]
          info[:port] = match[:port] ? Integer(match[:port]) : (info[:ssl] ? 8883 : 1883)
          info[:username] = match[:username] if match[:username]
          info[:password] = match[:password] if match[:password]
        else
          info[:host] = uri
        end
      end
      info.merge(overrides)
    end
  end
  
end

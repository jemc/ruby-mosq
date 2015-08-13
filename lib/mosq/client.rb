
require 'socket'

require_relative 'client/bucket'


module Mosq
  class Client
    
    # Raised when an operation is performed on an already-destroyed {Client}.
    class DestroyedError < RuntimeError; end
    
    # Create a new {Client} instance with the given properties.
    def initialize(*args)
      @options = Util.connection_info(*args)
      
      @options[:heartbeat] ||= 30 # seconds
      @protocol_timeout = DEFAULT_PROTOCOL_TIMEOUT
      
      Util.null_check "creating the client",
        (@ptr = FFI.mosquitto_new(@options[:client_id], true, nil))
      
      @bucket = Bucket.new(@ptr)
      @event_handlers = {}
      
      @packet_id_ptr = Util.mem_ptr(:int)
      
      @finalizer = self.class.create_finalizer_for(@ptr)
      ObjectSpace.define_finalizer(self, @finalizer)
    end
    
    # @api private
    def self.create_finalizer_for(ptr)
      Proc.new do
        FFI.mosquitto_destroy(ptr)
      end
    end
    
    def username;  @options.fetch(:username);  end
    def password;  @options.fetch(:password);  end
    def host;      @options.fetch(:host);      end
    def port;      @options.fetch(:port);      end
    def ssl?;      @options.fetch(:ssl);       end
    def heartbeat; @options.fetch(:heartbeat); end
    
    # The maximum time interval the user application should wait between
    # yielding control back to the client object by calling methods like
    # {#run_loop!} and {#run_immediate!}.
    def max_poll_interval
      @options.fetch(:heartbeat) / 2.0
    end
    
    def ptr
      raise DestroyedError unless @ptr
      @ptr
    end
    private :ptr
    
    # Initiate the connection with the server.
    # It is necessary to call this before any other communication.
    def start
      Util.error_check "configuring the username and password",
        FFI.mosquitto_username_pw_set(ptr, @options[:usernam], @options[:password])
      
      Util.error_check "connecting to #{@options[:host]}",
        FFI.mosquitto_connect(ptr, @options[:host], @options[:port], @options[:heartbeat])
      
      @ruby_socket = Socket.for_fd(FFI.mosquitto_socket(ptr))
      @ruby_socket.autoclose = false
      
      res = fetch_response(:connect, nil)
      raise Mosq::FFI::Error::NoConn, res.fetch(:message) \
        unless res.fetch(:status) == 0
      
      self
    end
    
    # Gracefully close the connection with the server.
    def close
      @ruby_socket = nil
      
      Util.error_check "closing the connection to #{@options[:host]}",
        FFI.mosquitto_disconnect(ptr)
      
      self
    rescue Mosq::FFI::Error::NoConn
      self
    end
    
    # Free the native resources associated with this object. This will
    # be done automatically on garbage collection if not called explicitly.
    def destroy
      if @finalizer
        @finalizer.call
        ObjectSpace.undefine_finalizer(self)
      end
      @ptr = @finalizer = @ruby_socket = @bucket = nil
      
      self
    end
    
    # Register a handler for events on the given channel of the given type.
    # Only one handler for each event type may be registered at a time.
    # If no callable or block is given, the handler will be cleared.
    #
    # @param type [Symbol] The type of event to watch for.
    # @param callable [#call,nil] The callable handler if no block is given.
    # @param block [Proc,nil] The handler block to register.
    # @return [Proc,#call,nil] The given block or callable.
    # @yieldparam event [Hash] The event passed to the handler.
    #
    def on_event(type, callable=nil, &block)
      handler = block || callable
      raise ArgumentError, "expected block or callable as the event handler" \
        unless handler.respond_to?(:call)
      
      @event_handlers[type.to_sym] = handler
      handler
    end
    alias_method :on, :on_event
    
    # Unregister the event handler associated with the given channel and method.
    #
    # @param type [Symbol] The type of protocol method to watch for.
    # @return [Proc,nil] This removed handler, if any.
    #
    def clear_event_handler(type)
      @event_handlers.delete(type.to_sym)
    end
    
    # The timeout to use when waiting for protocol events, in seconds.
    # By default, this has the value of {DEFAULT_PROTOCOL_TIMEOUT}.
    # When set, it affects operations like {#run_loop!}.
    attr_accessor :protocol_timeout
    DEFAULT_PROTOCOL_TIMEOUT = 30 # seconds
    
    # Subscribe to the given topic. Messages with matching topic will be
    # delivered to the {:message} event handler registered with {on_event}.
    #
    # @param topic [String] The topic patten to subscribe to.
    # @param qos [Integer] The QoS level to expect for received messages.
    # @return [Client] This client.
    #
    def subscribe(topic, qos: 0)
      Util.error_check "subscribing to a topic",
        FFI.mosquitto_subscribe(ptr, @packet_id_ptr, topic, qos)
      
      fetch_response(:subscribe, @packet_id_ptr.read_int)
      
      self
    end
    
    # Unsubscribe from the given topic.
    #
    # @param topic [String] The topic patten to unsubscribe from.
    # @return [Client] This client.
    #
    def unsubscribe(topic)
      Util.error_check "unsubscribing from a topic",
        FFI.mosquitto_unsubscribe(ptr, @packet_id_ptr, topic)
      
      fetch_response(:unsubscribe, @packet_id_ptr.read_int)
      
      self
    end
    
    # Publish a message with the given topic and payload.
    #
    # @param topic [String] The topic to publish on.
    # @param payload [String] The payload to publish.
    # @param qos [Integer] The QoS level to use for the publish transaction.
    # @param retain [Boolean] Whether the broker should retain the message.
    # @return [Client] This client.
    #
    def publish(topic, payload, qos: 0, retain: false)
      Util.error_check "publishing a message",
        FFI.mosquitto_publish(ptr, @packet_id_ptr,
          topic, payload.bytesize, payload, qos, retain)
      
      fetch_response(:publish, @packet_id_ptr.read_int)
      
      self
    end
    
    # Fetch and handle events in a loop that blocks the calling thread.
    # The loop will continue until the {#break!} method is called from within
    # an event handler, or until the given timeout duration has elapsed.
    # Note that this must be called at least as frequently as the heartbeat
    # interval to ensure that the client is not disconnected - if control is
    # not yielded to the client transport heartbeats will not be maintained.
    #
    # @param timeout [Float] the maximum time to run the loop, in seconds;
    #   if none is given, the value is {#protocol_timeout} or until {#break!}
    # @param block [Proc,nil] if given, the block will be yielded each
    #   non-exception event received on any channel. Other handlers or
    #   response fetchings that match the event will still be processed,
    #   as the block does not consume the event or replace the handlers.
    # @return [undefined] assume no value - reserved for future use.
    #
    def run_loop!(timeout: protocol_timeout, &block)
      timeout = Float(timeout) if timeout
      fetch_events(timeout, &block)
      nil
    end
    
    # Yield control to the client object to do any connection-oriented work
    # that needs to be done, including heartbeating. This is the same as
    # calling {#run_loop!} with no block and a timeout of 0.
    #
    def run_immediate!
      run_loop!(timeout: 0)
    end
    
    # Stop iterating from within an execution of the {#run_loop!} method.
    # Call this method only from within an event handler.
    # It will take effect only after the handler finishes running.
    #
    # @return [nil]
    #
    def break!
      @breaking = true
      nil
    end
    
    private
    
    # Calculate the amount of the timeout remaining from the given start time
    def remaining_timeout(timeout=0, start=Time.now)
      return nil unless timeout
      timeout = timeout - (Time.now - start)
      timeout < 0 ? 0 : timeout
    end
    
    # Block until there is readable data on the internal ruby socket,
    # returning true if there is readable data, or false if time expired.
    def select(timeout=0)
      return false unless @ruby_socket
      IO.select([@ruby_socket], [], [], timeout) ? true : false
    rescue Errno::EBADF
      false
    end
    
    # Execute the handler for this type of event, if any.
    def handle_incoming_event(event)
      if (handler = (@event_handlers[event.fetch(:type)]))
        handler.call(event)
      end
    end
    
    def connection_housekeeping
      # Do any pending outbound writes.
      while FFI.mosquitto_want_write(ptr)
        Util.error_check "sending outbound packets",
          FFI.mosquitto_loop_write(ptr, 1)
      end
      
      # Do any pending stateful protocol packets.
      Util.error_check "handling stateful protocol packets",
        FFI.mosquitto_loop_misc(ptr)
    end
    
    # Return the next incoming event as a Hash, or nil if time expired.
    def fetch_next_event(timeout=0, start=Time.now)
      max_timeout = max_poll_interval
      
      # Check if any data is immediately available to read
      if select(0)
        Util.error_check "reading immediate inbound packets",
          FFI.mosquitto_loop_read(ptr, 1)
      end
      
      while true
        connection_housekeeping
        
        # Check for an event already waiting in the bucket
        return @bucket.events.shift unless @bucket.events.empty?
        
        # Calculate remaining timeout and break if breaking or time expired.
        remaining = remaining_timeout(timeout, start)
        return nil if remaining && remaining <= 0
        
        # Wait for data to arrive on the socket.
        select_timeout = remaining ? [remaining, max_timeout].min : nil
        if select(select_timeout)
          Util.error_check "reading inbound packets",
            FFI.mosquitto_loop_read(ptr, 1)
          
          unless @bucket.events.empty?
            connection_housekeeping
            return @bucket.events.shift
          end
        end
      end
    end
    
    # Internal implementation of the {#run_loop!} method.
    def fetch_events(timeout=protocol_timeout, start=Time.now)
      while (event = fetch_next_event(timeout, start))
        handle_incoming_event(event)
        yield event if block_given?
        break if @breaking
      end
    end
    
    # Internal implementation of synchronous responses.
    def fetch_response(expected_type, expected_packet_id, timeout=protocol_timeout, start=Time.now)
      unwanted_events = []
      
      while (event = fetch_next_event(timeout, start))
        if (event.fetch(:type) == expected_type) && (
          !expected_packet_id ||
            event.fetch(:packet_id) == expected_packet_id
          )
          unwanted_events.reverse_each { |e| @bucket.events.unshift(e) }
          handle_incoming_event(event)
          return event
        else
          unwanted_events.push(event)
        end
      end
      
      raise FFI::Error::Timeout, "waiting for #{expected_type} response"
    end
  end
end

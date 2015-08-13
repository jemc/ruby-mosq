
module Mosq
  class Client
    
    # @api private
    class Bucket
      def initialize(ptr)
        @events    = []
        @callbacks = {}
        
        FFI.mosquitto_connect_callback_set     ptr, new_callback(:on_connect)
        # FFI.mosquitto_disconnect_callback_set  ptr, new_callback(:on_disconnect)
        FFI.mosquitto_publish_callback_set     ptr, new_callback(:on_publish)
        FFI.mosquitto_message_callback_set     ptr, new_callback(:on_message)
        FFI.mosquitto_subscribe_callback_set   ptr, new_callback(:on_subscribe)
        FFI.mosquitto_unsubscribe_callback_set ptr, new_callback(:on_unsubscribe)
        # FFI.mosquitto_log_callback_set         ptr, new_callback(:on_log)
      end
      
      def new_callback(symbol)
        # This ensures that callback Procs are retained in the Bucket,
        # and are not garbage-collected for the entire life of the Client.
        # If the callback Procs are garbage-collected then invoked, SIGSEGV!
        @callbacks[symbol] = method(symbol).to_proc
      end
      
      attr_reader :events
      
      def on_connect(ptr, _, status)
        @events << {
          type:    :connect,
          status:  status,
          message: case status
                   when 0; "connection accepted"
                   when 1; "connection refused (unacceptable protocol version)"
                   when 2; "connection refused (identifier rejected)"
                   when 3; "connection refused (broker unavailable)"
                   when 4; "connection refused (bad user name or password)"
                   when 5; "connection refused (not authorised)"
                   when 6; "connection refused (unknown reason)"
                   else    "unknown connection failure"
                   end,
        }
      end
      
      # def on_disconnect(ptr, _, status)
        
      # end
      
      def on_publish(ptr, _, packet_id)
        @events << {
          type:      :publish,
          packet_id: packet_id,
        }
      end
      
      def on_message(ptr, _, message)
        @events << {
          type:     :message,
          topic:    message[:topic].read_string,
          payload:  message[:payload].read_bytes(message[:payloadlen]),
          retained: message[:retain],
          qos:      message[:qos],
        }
      end
      
      def on_subscribe(ptr, _, packet_id, _, _)
        @events << {
          type:      :subscribe,
          packet_id: packet_id,
        }
      end
      
      def on_unsubscribe(ptr, _, packet_id)
        @events << {
          type:      :unsubscribe,
          packet_id: packet_id,
        }
      end
      
      # def on_log(ptr, _, status, string)
        
      # end
    end
    
  end
end

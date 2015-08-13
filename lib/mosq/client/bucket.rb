
module Mosq
  class Client
    
    # @api private
    class Bucket
      def initialize(ptr)
        FFI.mosquitto_connect_callback_set     ptr, method(:on_connect)
        # FFI.mosquitto_disconnect_callback_set  ptr, method(:on_disconnect)
        FFI.mosquitto_publish_callback_set     ptr, method(:on_publish)
        FFI.mosquitto_message_callback_set     ptr, method(:on_message)
        FFI.mosquitto_subscribe_callback_set   ptr, method(:on_subscribe)
        FFI.mosquitto_unsubscribe_callback_set ptr, method(:on_unsubscribe)
        # FFI.mosquitto_log_callback_set         ptr, method(:on_log)
        
        @events = []
      end
      
      attr_reader :events
      
      def on_connect(ptr, _, status)
        @events << {
          type:    :connect,
          status:  status,
          message: case status
                   when 0; "success"
                   when 1; "connection refused (unacceptable protocol version)"
                   when 2; "connection refused (identifier rejected)"
                   when 3; "connection refused (broker unavailable)"
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

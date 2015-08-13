
require 'ffi'


module Mosq
  
  # Bindings and wrappers for the native functions and structures exposed by
  # the libmosquitto C library. This module is for internal use only so that
  # all dependencies on the implementation of the C library are abstracted.
  # @api private
  module FFI
    extend ::FFI::Library
    
    libfile = "libmosquitto.#{::FFI::Platform::LIBSUFFIX}"
    
    ffi_lib ::FFI::Library::LIBC
    ffi_lib \
      File.expand_path("../../ext/mosq/#{libfile}", File.dirname(__FILE__))
    
    opts = {
      blocking: true  # only necessary on MRI to deal with the GIL.
    }
    
    attach_function :free,   [:pointer], :void,    **opts
    attach_function :malloc, [:size_t],  :pointer, **opts
    
    class Boolean
      extend ::FFI::DataConverter
      native_type ::FFI::TypeDefs[:int]
      def self.to_native val, ctx;   val ? 1 : 0; end
      def self.from_native val, ctx; val != 0;    end
    end
    
    class Message < ::FFI::Struct
      layout :mid,        :int,
             :topic,      :pointer,
             :payload,    :pointer,
             :payloadlen, :int,
             :qos,        :int,
             :retain,     Boolean
    end
    
    Status = enum ::FFI::TypeDefs[:int], [
      :conn_pending, -1,
      :success,       0,
      :nomem,         1,
      :protocol,      2,
      :inval,         3,
      :no_conn,       4,
      :conn_refused,  5,
      :not_found,     6,
      :conn_lost,     7,
      :tls,           8,
      :payload_size,  9,
      :not_supported, 10,
      :auth,          11,
      :acl_denied,    12,
      :unknown,       13,
      :errno,         14,
      :eai,           15,
      :proxy,         16,
    ]
    
    Option = enum [
      :protocol_version, 1,
    ]
    
    client = :pointer
    
    callback :on_connect,     [client, :pointer, :int],                 :void
    callback :on_disconnect,  [client, :pointer, :int],                 :void
    callback :on_publish,     [client, :pointer, :int],                 :void
    callback :on_message,     [client, :pointer, Message.ptr],          :void
    callback :on_subscribe,   [client, :pointer, :int, :int, :pointer], :void
    callback :on_unsubscribe, [client, :pointer, :int],                 :void
    callback :on_log,         [client, :pointer, :int, :string],        :void
    
    attach_function :mosquitto_lib_version,               [:pointer, :pointer, :pointer],                             Status,  **opts
    attach_function :mosquitto_lib_init,                  [],                                                         Status,  **opts
    attach_function :mosquitto_lib_cleanup,               [],                                                         Status,  **opts
    attach_function :mosquitto_new,                       [:string, Boolean, :pointer],                               client,  **opts
    attach_function :mosquitto_destroy,                   [client],                                                   :void,   **opts
    attach_function :mosquitto_reinitialise,              [client, :string, Boolean, :pointer],                       Status,  **opts
    attach_function :mosquitto_will_set,                  [client, :string, :int, :pointer, :int, Boolean],           Status,  **opts
    attach_function :mosquitto_will_clear,                [client],                                                   Status,  **opts
    attach_function :mosquitto_username_pw_set,           [client, :string, :string],                                 Status,  **opts
    attach_function :mosquitto_connect,                   [client, :string, :int, :int],                              Status,  **opts
    attach_function :mosquitto_connect_bind,              [client, :string, :int, :int, :string],                     Status,  **opts
    attach_function :mosquitto_connect_async,             [client, :string, :int, :int],                              Status,  **opts
    attach_function :mosquitto_connect_bind_async,        [client, :string, :int, :int, :string],                     Status,  **opts
    attach_function :mosquitto_connect_srv,               [client, :string, :int, :string],                           Status,  **opts
    attach_function :mosquitto_reconnect,                 [client],                                                   Status,  **opts
    attach_function :mosquitto_reconnect_async,           [client],                                                   Status,  **opts
    attach_function :mosquitto_disconnect,                [client],                                                   Status,  **opts
    attach_function :mosquitto_publish,                   [client, :pointer, :string, :int, :pointer, :int, Boolean], Status,  **opts
    attach_function :mosquitto_subscribe,                 [client, :pointer, :string, :int],                          Status,  **opts
    attach_function :mosquitto_unsubscribe,               [client, :pointer, :string],                                Status,  **opts
    attach_function :mosquitto_message_copy,              [Message.ptr, Message.ptr],                                 Status,  **opts
    attach_function :mosquitto_message_free,              [:pointer],                                                 :void,   **opts
    attach_function :mosquitto_loop,                      [client, :int, :int],                                       Status,  **opts
    attach_function :mosquitto_loop_forever,              [client, :int, :int],                                       Status,  **opts
    attach_function :mosquitto_loop_start,                [client],                                                   Status,  **opts
    attach_function :mosquitto_loop_stop,                 [client, Boolean],                                          Status,  **opts
    attach_function :mosquitto_socket,                    [client],                                                   :int,    **opts
    attach_function :mosquitto_loop_read,                 [client, :int],                                             Status,  **opts
    attach_function :mosquitto_loop_write,                [client, :int],                                             Status,  **opts
    attach_function :mosquitto_loop_misc,                 [client],                                                   Status,  **opts
    attach_function :mosquitto_want_write,                [client],                                                   :bool,   **opts
    attach_function :mosquitto_threaded_set,              [client, Boolean],                                          Status,  **opts
    attach_function :mosquitto_opts_set,                  [client, Option, :pointer],                                 Status,  **opts
    attach_function :mosquitto_tls_set,                   [client],                                                   Status,  **opts
    attach_function :mosquitto_tls_insecure_set,          [client, Boolean],                                          Status,  **opts
    attach_function :mosquitto_tls_opts_set,              [client, :int, :string, :string],                           Status,  **opts
    attach_function :mosquitto_tls_psk_set,               [client, :string, :string, :string],                        Status,  **opts
    attach_function :mosquitto_connect_callback_set,      [client, :on_connect],                                      :void,   **opts
    attach_function :mosquitto_disconnect_callback_set,   [client, :on_disconnect],                                   :void,   **opts
    attach_function :mosquitto_publish_callback_set,      [client, :on_publish],                                      :void,   **opts
    attach_function :mosquitto_message_callback_set,      [client, :on_message],                                      :void,   **opts
    attach_function :mosquitto_subscribe_callback_set,    [client, :on_subscribe],                                    :void,   **opts
    attach_function :mosquitto_unsubscribe_callback_set,  [client, :on_unsubscribe],                                  :void,   **opts
    attach_function :mosquitto_log_callback_set,          [client, :on_log],                                          :void,   **opts
    attach_function :mosquitto_reconnect_delay_set,       [client, :uint, :uint, Boolean],                            Status,  **opts
    attach_function :mosquitto_max_inflight_messages_set, [client, :uint],                                            Status,  **opts
    attach_function :mosquitto_message_retry_set,         [client, :uint],                                            :void,   **opts
    attach_function :mosquitto_user_data_set,             [client, :pointer],                                         :void,   **opts
    attach_function :mosquitto_socks5_set,                [client, :string, :int, :string, :string],                  Status,  **opts
    attach_function :mosquitto_strerror,                  [Status],                                                   :string, **opts
    attach_function :mosquitto_connack_string,            [:int],                                                     :string, **opts
    attach_function :mosquitto_sub_topic_tokenise,        [:string, :pointer, :pointer],                              Status,  **opts
    attach_function :mosquitto_sub_topic_tokens_free,     [:pointer, :int],                                           Status,  **opts
    attach_function :mosquitto_topic_matches_sub,         [:string, :string, :pointer],                               Status,  **opts
    attach_function :mosquitto_pub_topic_check,           [:string],                                                  Status,  **opts
    attach_function :mosquitto_sub_topic_check,           [:string],                                                  Status,  **opts
  end
end

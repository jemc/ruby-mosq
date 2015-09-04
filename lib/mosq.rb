
require_relative 'mosq/util'
require_relative 'mosq/ffi'
require_relative 'mosq/ffi/error'

require_relative 'mosq/client'

# Call to initialize the library
Mosq::Util.error_check "initializing the libmosquitto library",
  Mosq::FFI.mosquitto_lib_init

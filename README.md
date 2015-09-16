# mosq

[![Gem Version](https://badge.fury.io/rb/mosq.png)](http://badge.fury.io/rb/mosq) 
[![Join the chat at https://gitter.im/jemc/ruby-mosq](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/jemc/ruby-mosq?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

A Ruby [MQTT](http://mqtt.org/) client library based on [FFI](https://github.com/ffi/ffi/wiki) bindings for [libmosquitto](http://mosquitto.org/man/libmosquitto-3.html).

##### `$ gem install mosq`

### System Requirements

The `mosq` gem requires `libffi-dev`, as well as the [requirements for building libmosquitto](http://git.eclipse.org/c/mosquitto/org.eclipse.mosquitto.git/tree/compiling.txt).  Note that on Linux, the library will be built with `make`, though on Mac OS X `cmake` is required.

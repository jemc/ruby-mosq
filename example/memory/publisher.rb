
require 'mosq'

# Publish batches of messages in a loop indefinitely,
# showing memory usage and other stats in between each batch.

batch_count = 500 # number of messages to fetch for each batch
sleep_time  = 0.1 # time in seconds to sleep in between each batch

publisher = Mosq::Client.new.start

while true
  batch = batch_count.times.map do |i|
    ["example/memory/#{i}", "message #{i} " * 100]
  end
  publisher.publish_many(batch, qos: 1)
  
  system "ps -u --pid #{Process.pid}"; puts
  publisher.run_loop!(timeout: sleep_time)
end

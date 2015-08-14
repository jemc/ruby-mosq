
require 'mosq'

# Consume batches of messages in a loop indefinitely,
# showing memory usage and other stats in between each batch.

batch_count = 500 # number of messages to fetch for each batch

consumer = Mosq::Client.new.start
consumer.subscribe("example/memory/#", qos: 1)

count = 0
consumer.on :message do |message|
  if (count += 1) >= batch_count
    system "ps -u --pid #{Process.pid}"; puts
    count = 0
  end
end

while true
  consumer.run_loop!
end

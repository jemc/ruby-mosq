
require 'securerandom'
require 'spec_helper'


describe Mosq::Client do
  let(:subject_class) { Mosq::Client }
  
  its(:heartbeat) { should eq 30 } # default value
  
  describe "destroy" do
    it "is not necessary to call" do
      subject
    end
    
    it "can be called several times to no additional effect" do
      subject.destroy
      subject.destroy
      subject.destroy
    end
    
    it "prevents any other network operations on the object" do
      subject.destroy
      expect { subject.start }.to raise_error Mosq::Client::DestroyedError
      expect { subject.close }.to raise_error Mosq::Client::DestroyedError
    end
  end
  
  describe "start" do
    it "initiates the connection to the server" do
      subject.start
    end
    
    it "can be called several times to reconnect" do
      subject.start
      subject.start
      subject.start
    end
  end
  
  describe "close" do
    it "closes the initiated connection" do
      subject.start
      subject.close
    end
    
    it "can be called several times to no additional effect" do
      subject.start
      subject.close
      subject.close
      subject.close
    end
    
    it "can be called before destroy" do
      subject.start
      subject.close
      subject.destroy
    end
    
    it "can be called before connecting to no effect" do
      subject.close
    end
  end
  
  it "uses Util.connection_info to parse info from its creation arguments" do
    args = ["parsable url", { foo: "bar" }]
    Mosq::Util.should_receive(:connection_info).with(*args) {{
      username: "username",
      password: "password",
      host:     "host",
      port:     1234,
      ssl:      false
    }}
    subject = subject_class.new(*args)
    
    subject.username.should eq "username"
    subject.password.should eq "password"
    subject.host    .should eq "host"
    subject.port    .should eq 1234
    subject.ssl?    .should eq false
  end
  
  describe "when connected" do
    before { subject.start }
    after  { subject.close }
    
    let(:topic) { "test/topic/#{SecureRandom.hex}" }
    let(:payload) { SecureRandom.hex }
    
    it "can subscribe to a topic" do
      subject.subscribe(topic).should eq subject
    end
    
    it "can unsubscribe from a topic" do
      subject.subscribe(topic)
      subject.unsubscribe(topic).should eq subject
    end
    
    it "can publish and get a message on a topic" do
      received = nil
      subject.on :message do |message|
        received = message
        subject.break!
      end
      
      subject.subscribe(topic)
      
      subject.publish(topic, payload)
      
      subject.run_loop!
      received.should eq ({
        type:     :message,
        topic:    topic,
        payload:  payload,
        retained: false,
        qos:      0,
      })
    end
    
    it "can publish a retained message then get it later" do
      received = nil
      subject.on :message do |message|
        received = message
        subject.break!
      end
      
      subject.publish(topic, payload, retain: true, qos: 2)
      
      subject.subscribe(topic)
      
      subject.run_loop!
      received.should eq ({
        type:     :message,
        topic:    topic,
        payload:  payload,
        retained: true,
        qos:      0,
      })
    end
    
    it "can publish and subscribe at a higher qos level" do
      received = nil
      subject.on :message do |message|
        received = message
        subject.break!
      end
      
      subject.subscribe(topic, qos: 2)
      
      subject.publish(topic, payload, qos: 2)
      
      subject.run_loop!
      received.should eq ({
        type:     :message,
        topic:    topic,
        payload:  payload,
        retained: false,
        qos:      2,
      })
    end
    
    it "can use run_loop! as an ad-hoc message handler" do
      subject.subscribe(topic)
      
      subject.publish(topic, payload)
      
      received = nil
      subject.run_loop! do |event|
        event.should eq ({
          type:     :message,
          topic:    topic,
          payload:  payload,
          retained: false,
          qos:      0,
        })
        received = true
        subject.break!
      end
      received.should eq true
    end
    
    it "can subscribe to many topics and publish many messages" do
      topics   = 500.times.map { |i| "#{topic}/#{i}" }
      payloads = topics.map { payload }
      
      received = []
      subject.on :message do |message|
        received << message
        subject.break! if received.size == topics.size
      end
      
      subject.subscribe_many(topics, qos: 2).should eq subject
      
      subject.publish_many(topics.zip(payloads), qos: 2, retain: false)
        .should eq subject
      
      subject.run_loop!
      
      subject.unsubscribe_many(topics).should eq subject
      
      received.each do |message|
        topic = message[:topic]
        topics.should include topic
        topics.delete(topic)
        
        message.should eq ({
          type:     :message,
          topic:    message[:topic],
          payload:  payload,
          retained: false,
          qos:      2,
        })
      end
    end
    
    describe "timeout" do
      describe "remaining_timeout" do
        it "returns nil when given a timeout of nil" do
          subject.__send__(:remaining_timeout, nil).should eq nil
        end
        
        it "returns 0 when time has already run out" do
          time_now = Time.now
          subject.__send__(:remaining_timeout, 0,   time_now)      .should eq 0
          subject.__send__(:remaining_timeout, 5.0, time_now - 5)  .should eq 0
          subject.__send__(:remaining_timeout, 5.0, time_now - 10) .should eq 0
          subject.__send__(:remaining_timeout, 5.0, time_now - 100).should eq 0
        end
        
        it "returns the remaining time when there is time remaining" do
          subject.__send__(:remaining_timeout, 10.0, Time.now-5)
            .should be_within(1.0).of(5.0)
        end
      end
      
      def assert_time_elapsed(less_than: nil, greater_than: nil)
        start = Time.now
        yield
      ensure
        time = Time.now - start
        time.should be < less_than    if less_than
        time.should be > greater_than if greater_than
      end
      
      def with_test_timeout(timeout)
        main = Thread.current
        Thread.new { sleep timeout; main.raise(RuntimeError, "test timeout") }
        yield
      rescue RuntimeError => e
        e.message.should eq "test timeout"
      end
      
      specify "of zero passed to run_loop!" do
        assert_time_elapsed less_than: 0.25 do
          subject.run_loop! timeout: 0 do
            assert nil, "This block should never be run"
          end
        end
      end
      
      specify "of zero passed to fetch_response" do
        expect {
          assert_time_elapsed less_than: 0.25 do
            subject.__send__(:fetch_response, :publish, 999, 0)
          end
        }.to raise_error Mosq::FFI::Error::Timeout
      end
      
      specify "of 0.25 passed to run_loop!" do
        assert_time_elapsed greater_than: 0.25 do
          subject.run_loop! timeout: 0.25 do
            assert nil, "This block should never be run"
          end
        end
      end
      
      specify "of 0.25 passed to fetch_response" do
        expect {
          assert_time_elapsed greater_than: 0.25 do
            subject.__send__(:fetch_response, :publish, 999, 0.25)
          end
        }.to raise_error Mosq::FFI::Error::Timeout
      end
      
      specify "of nil passed to run_loop!" do
        with_test_timeout 0.25 do
          assert_time_elapsed greater_than: 0.2 do
            subject.run_loop! timeout: nil do
              assert nil, "This block should never be run"
            end
          end
        end
      end
      
      specify "of nil passed to fetch_response" do
        with_test_timeout 0.25 do
          assert_time_elapsed greater_than: 0.2 do
            subject.__send__(:fetch_response, :publish, 999, nil)
          end
        end
      end
    end
  end
  
  describe "with a short heartbeat interval" do
    subject { subject_class.new(heartbeat: 2) }
    
    its(:heartbeat) { should eq 2 }
    
    # The server's grace period is 3/2 the heartbeat interval. (MQTT-3.1.2-24)
    let(:expire_time) { subject.heartbeat * 3/2.0 + 0.5 }
    
    let(:progress_thread) { Thread.new {
      progress = "ₒoOᴼ'` `'ᴼOoₒ"
      count = progress.size + 1
      count.times { |i| sleep expire_time / count; print progress[i] } }
    }
    before { progress_thread }
    after  { progress_thread.kill }
    
    it "gets disconnected when control is not yielded" do
      subject.start
      sleep expire_time
      
      expect {
        subject.subscribe("test/topic")
      }.to raise_error Mosq::FFI::Error::ConnLost
    end
    
    it "stays connected when control is continuously yielded" do
      subject.start
      subject.run_loop!(timeout: expire_time)
      
      subject.subscribe("test/topic")
      subject.close
    end
    
    it "stays connected when control is occasionally yielded" do
      subject.start
      
      (expire_time / subject.max_poll_interval).to_i.times do
        sleep subject.max_poll_interval
        subject.run_immediate!
      end
      sleep expire_time % subject.max_poll_interval
      
      subject.subscribe("test/topic")
      subject.close
    end
  end
  
end

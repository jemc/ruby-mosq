
require 'spec_helper'


describe Mosq::Util do
  
  describe "connection_info" do
    it "given no arguments returns default values" do
      subject.connection_info.should eq(
        host: "localhost",
        port: 1883,
        ssl:  false
      )
    end
    
    it "given a bare hostname uses that hostname" do
      subject.connection_info("host").should eq(
        host: "host",
        port: 1883,
        ssl:  false
      )
    end
    
    it "given a URL parses values from the URL" do
      subject.connection_info(
        "mqtt://username:password@host:1234"
      ).should eq(
        username: "username",
        password: "password",
        host:     "host",
        port:     1234,
        ssl:      false
      )
      
      subject.connection_info(
        "mqtt://host"
      ).should eq(
        host: "host",
        port: 1883,
        ssl:  false
      )
      
      subject.connection_info(
        "mqtt://username@host:1234"
      ).should eq(
        username: "username",
        host:     "host",
        port:     1234,
        ssl:      false
      )
    end
    
    it "given an SSL URL parses values from the URL" do
      subject.connection_info(
        "mqtts://username:password@host:1234"
      ).should eq(
        username: "username",
        password: "password",
        host:     "host",
        port:     1234,
        ssl:      true
      )
    end
    
    it "uses the default SSL port with an SSL URL with no port given" do
      subject.connection_info(
        "mqtts://host"
      ).should eq(
        host: "host",
        port: 8883,
        ssl:  true
      )
    end
    
    it "given options overrides the default values with the options" do
      subject.connection_info(
        username: "foo",
        password: "bar",
        port:     5678,
        ssl:      true
      ).should eq(
        username: "foo",
        password: "bar",
        host:     "localhost",
        port:     5678,
        ssl:      true
      )
    end
    
    it "given a URL and options overrides the parsed values with the options" do
      subject.connection_info(
        "mqtt://username:password@host:1234",
        username: "foo",
        password: "bar",
        port:     5678,
        ssl:      true
      ).should eq(
        username: "foo",
        password: "bar",
        host:     "host",
        port:     5678,
        ssl:      true
      )
    end
  end
  
end

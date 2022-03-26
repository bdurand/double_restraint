# frozen_string_literal: true

require_relative "spec_helper"

describe DoubleRestraint do

  let(:restraint) { DoubleRestraint.new(:test, limit: 3, timeout: 0.01, long_running_timeout: 0.1, long_running_limit: 2)}

  it "should pass the timeout to the block" do
    retval = restraint.execute do |timeout|
      timeout
    end
    expect(retval).to eq 0.01
  end

  it "should restrain the number of processes executing at once" do
    threads = []
    begin
      threads << Thread.new { restraint.execute { |timeout| sleep(0.1) } }
      threads << Thread.new { restraint.execute { |timeout| sleep(0.1) } }
      threads << Thread.new { restraint.execute { |timeout| sleep(0.1) } }
      sleep(0.05)
      expect { restraint.execute { |timeout| } }.to raise_error(Restrainer::ThrottledError)
    ensure
      threads.each { |thread| thread.join }
    end
  end

  it "should pass the long running timeout to the block if the first pass times out" do
    timeouts = []
    restraint.execute do |timeout|
      timeouts << timeout
      raise TimeoutError if timeouts.size == 1
    end
    expect(timeouts).to eq [0.01, 0.1]
  end

  it "should restrain the number of long running processes" do
    threads = []
    begin
      threads << Thread.new { restraint.execute { |timeout| timeout == 0.01 ? raise(TimeoutError) : sleep(0.1) } }
      threads << Thread.new { restraint.execute { |timeout| timeout == 0.01 ? raise(TimeoutError) : sleep(0.1) } }
      sleep(0.05)
      expect { restraint.execute { |timeout| raise TimeoutError if timeout == 0.01 } }.to raise_error(Restrainer::ThrottledError)
    ensure
      threads.each { |thread| thread.join }
    end
  end

  it "should raise non-timeout errors in the block" do
    expect { restraint.execute { |timeout| raise ArgumentError if timeout == 0.01 } }.to raise_error(ArgumentError)
  end

  it "should be able to specify what constitutes a timeout error" do
    restraint = DoubleRestraint.new(:test, limit: 3, timeout: 0.01, long_running_timeout: 0.1, long_running_limit: 2, timeout_errors: ArgumentError)
    timeouts = []
    restraint.execute do |timeout|
      timeouts << timeout
      raise ArgumentError if timeouts.size == 1
    end
    expect(timeouts).to eq [0.01, 0.1]
  end

end

# frozen_string_literal: true

require_relative "spec_helper"

describe DoubleRestraint do
  let(:restraint) { DoubleRestraint.new(:test, limit: 3, timeout: 1, long_running_timeout: 3, long_running_limit: 2) }

  it "should pass the timeout to the block" do
    retval = restraint.execute do |timeout|
      timeout
    end
    expect(retval).to eq 1
  end

  it "should not require a limit" do
    restraint = DoubleRestraint.new(:test, timeout: 1, long_running_timeout: 3, long_running_limit: 2)
    retval = restraint.execute do |timeout|
      timeout
    end
    expect(retval).to eq 1
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
      raise Timeout::Error if timeouts.size == 1
    end
    expect(timeouts).to eq [1, 3]
  end

  it "should restrain the number of long running processes" do
    threads = []
    begin
      threads << Thread.new { restraint.execute { |timeout| timeout == 1 ? raise(Timeout::Error) : sleep(0.1) } }
      threads << Thread.new { restraint.execute { |timeout| timeout == 1 ? raise(Timeout::Error) : sleep(0.1) } }
      sleep(0.05)
      expect { restraint.execute { |timeout| raise Timeout::Error if timeout == 1 } }.to raise_error(Restrainer::ThrottledError)
    ensure
      threads.each { |thread| thread.join }
    end
  end

  it "should raise non-timeout errors in the block" do
    expect { restraint.execute { |timeout| raise ArgumentError if timeout == 1 } }.to raise_error(ArgumentError)
  end

  it "should be able to specify what constitutes a timeout error" do
    restraint = DoubleRestraint.new(:test, limit: 3, timeout: 1, long_running_timeout: 3, long_running_limit: 2, timeout_errors: ArgumentError)
    timeouts = []
    restraint.execute do |timeout|
      timeouts << timeout
      raise ArgumentError if timeouts.size == 1
    end
    expect(timeouts).to eq [1, 3]
  end
end

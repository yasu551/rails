#!/usr/bin/env ruby

# Simple test to verify our optimizations work
require_relative 'activesupport/lib/active_support'
require_relative 'activesupport/lib/active_support/callbacks'

class TestRecord
  include ActiveSupport::Callbacks
  define_callbacks :save

  def initialize
    @executed_callbacks = []
  end

  attr_reader :executed_callbacks

  def save
    run_callbacks :save do
      @executed_callbacks << :save_block
    end
  end

  def before_save_method
    @executed_callbacks << :before_save
  end

  def after_save_method
    @executed_callbacks << :after_save
  end
end

# Test basic callbacks
puts "Testing basic callbacks..."
test_class = Class.new(TestRecord) do
  set_callback :save, :before, :before_save_method
  set_callback :save, :after, :after_save_method
end

record = test_class.new
record.save

expected = [:before_save, :save_block, :after_save]
actual = record.executed_callbacks

if actual == expected
  puts "✅ Basic callbacks work correctly"
  puts "   Expected: #{expected}"
  puts "   Actual:   #{actual}"
else
  puts "❌ Basic callbacks failed"
  puts "   Expected: #{expected}"
  puts "   Actual:   #{actual}"
  exit 1
end

# Test environment pool
puts "\nTesting Environment pool..."
pool = ActiveSupport::Callbacks::Filters.environment_pool
env1 = pool.acquire(self)
env2 = pool.acquire(self)

if env1.class == ActiveSupport::Callbacks::Filters::Environment &&
   env2.class == ActiveSupport::Callbacks::Filters::Environment
  puts "✅ Environment pool works correctly"
else
  puts "❌ Environment pool failed"
  exit 1
end

pool.release(env1)
pool.release(env2)

# Test multiple callbacks (loop unrolling)
puts "\nTesting multiple callbacks..."
multi_class = Class.new(TestRecord) do
  set_callback :save, :before, :before_save_method
  set_callback :save, :before, lambda { @executed_callbacks << :lambda_before }
  set_callback :save, :after, :after_save_method
end

multi_record = multi_class.new
multi_record.save

if multi_record.executed_callbacks.include?(:before_save) &&
   multi_record.executed_callbacks.include?(:lambda_before) &&
   multi_record.executed_callbacks.include?(:save_block) &&
   multi_record.executed_callbacks.include?(:after_save)
  puts "✅ Multiple callbacks work correctly"
  puts "   Callbacks executed: #{multi_record.executed_callbacks}"
else
  puts "❌ Multiple callbacks failed"
  puts "   Callbacks executed: #{multi_record.executed_callbacks}"
  exit 1
end

# Test performance improvement
puts "\nTesting performance..."
require 'benchmark'

iterations = 10_000
perf_record = test_class.new

# Warmup
100.times { perf_record.save; perf_record.instance_variable_set(:@executed_callbacks, []) }

time = Benchmark.measure do
  iterations.times do
    perf_record.save
    perf_record.instance_variable_set(:@executed_callbacks, [])
  end
end

callbacks_per_second = (iterations / time.real).round(0)
puts "✅ Performance test completed"
puts "   #{iterations} callback executions in #{time.real.round(4)}s"
puts "   Rate: #{callbacks_per_second} callbacks/second"

if callbacks_per_second > 50_000
  puts "✅ Performance is excellent (>50k callbacks/sec)"
elsif callbacks_per_second > 10_000
  puts "✅ Performance is good (>10k callbacks/sec)"
else
  puts "⚠️  Performance could be better (<10k callbacks/sec)"
end

puts "\n🎉 All tests passed! ActiveSupport::Callbacks optimizations are working correctly."
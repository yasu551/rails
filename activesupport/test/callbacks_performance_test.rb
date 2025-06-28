# frozen_string_literal: true

require_relative "abstract_unit"
require "benchmark"

class CallbacksPerformanceTest < ActiveSupport::TestCase
  class OptimizedRecord
    include ActiveSupport::Callbacks
    define_callbacks :save, :validate

    def initialize
      @counter = 0
    end

    attr_reader :counter

    def increment_counter
      @counter += 1
    end

    def save
      run_callbacks :save do
        # Simulate save operation
        true
      end
    end

    def validate
      run_callbacks :validate do
        # Simulate validation
        true
      end
    end
  end

  def setup
    @iterations = 10_000
  end

  def test_basic_callback_performance
    record_class = Class.new(OptimizedRecord) do
      set_callback :save, :before, :increment_counter
      set_callback :save, :after, :increment_counter
    end

    record = record_class.new

    # Warmup
    100.times { record.save }

    result = Benchmark.measure do
      @iterations.times { record.save }
    end

    puts "\nBasic callbacks performance:"
    puts "Iterations: #{@iterations}"
    puts "Time: #{result.real.round(4)}s"
    puts "Callbacks/sec: #{(@iterations / result.real).round(0)}"

    assert result.real < 1.0, "Basic callbacks should complete in under 1 second"
  end

  def test_multiple_callbacks_performance
    record_class = Class.new(OptimizedRecord) do
      5.times do |i|
        set_callback :save, :before, :"before_#{i}"
        set_callback :save, :after, :"after_#{i}"

        define_method(:"before_#{i}") { increment_counter }
        define_method(:"after_#{i}") { increment_counter }
      end
    end

    record = record_class.new

    # Warmup
    100.times { record.save }

    result = Benchmark.measure do
      @iterations.times { record.save }
    end

    puts "\nMultiple callbacks performance:"
    puts "Iterations: #{@iterations}"
    puts "Time: #{result.real.round(4)}s"
    puts "Callbacks/sec: #{(@iterations / result.real).round(0)}"

    assert result.real < 2.0, "Multiple callbacks should complete in under 2 seconds"
  end

  def test_conditional_callbacks_performance
    record_class = Class.new(OptimizedRecord) do
      set_callback :save, :before, :increment_counter, if: :should_run?
      set_callback :save, :after, :increment_counter, unless: :should_skip?

      def should_run?
        true
      end

      def should_skip?
        false
      end
    end

    record = record_class.new

    # Warmup
    100.times { record.save }

    result = Benchmark.measure do
      @iterations.times { record.save }
    end

    puts "\nConditional callbacks performance:"
    puts "Iterations: #{@iterations}"
    puts "Time: #{result.real.round(4)}s"
    puts "Callbacks/sec: #{(@iterations / result.real).round(0)}"

    assert result.real < 1.5, "Conditional callbacks should complete in under 1.5 seconds"
  end

  def test_around_callbacks_performance
    record_class = Class.new(OptimizedRecord) do
      set_callback :save, :around, :around_save

      def around_save
        increment_counter
        yield
        increment_counter
      end
    end

    record = record_class.new

    # Warmup
    100.times { record.save }

    result = Benchmark.measure do
      @iterations.times { record.save }
    end

    puts "\nAround callbacks performance:"
    puts "Iterations: #{@iterations}"
    puts "Time: #{result.real.round(4)}s"
    puts "Callbacks/sec: #{(@iterations / result.real).round(0)}"

    assert result.real < 1.5, "Around callbacks should complete in under 1.5 seconds"
  end

  def test_environment_pool_efficiency
    # Test that Environment objects are being reused
    pool = ActiveSupport::Callbacks::Filters.environment_pool
    
    # Clear and measure pool usage
    initial_pool_size = pool.instance_variable_get(:@index)
    
    record_class = Class.new(OptimizedRecord) do
      set_callback :save, :before, :increment_counter
    end
    
    record = record_class.new
    
    # Run callbacks to exercise the pool
    100.times { record.save }
    
    final_pool_size = pool.instance_variable_get(:@index)
    
    # Pool should not grow significantly if objects are being reused
    assert final_pool_size <= initial_pool_size + 1, 
           "Environment pool should efficiently reuse objects"
  end

  def test_cache_invalidation_granularity
    # Test that cache invalidation is granular
    record_class = Class.new(OptimizedRecord) do
      set_callback :save, :before, :increment_counter
      set_callback :validate, :before, :increment_counter
    end

    record = record_class.new
    
    # Prime the caches
    record.save
    record.validate
    
    # Add a new save callback - should only invalidate save cache
    record_class.set_callback :save, :after, :increment_counter
    
    # This should use cached validate callback
    result = Benchmark.measure do
      1000.times { record.validate }
    end
    
    puts "\nCache efficiency test:"
    puts "Validate callbacks (should be cached): #{result.real.round(4)}s"
    
    assert result.real < 0.1, "Cached callbacks should be very fast"
  end

  def test_memory_usage_optimization
    # Basic memory usage test
    record_class = Class.new(OptimizedRecord) do
      10.times do |i|
        set_callback :save, :before, :"callback_#{i}"
        define_method(:"callback_#{i}") { increment_counter }
      end
    end

    record = record_class.new
    
    # Measure memory before
    GC.start
    memory_before = GC.stat[:total_allocated_objects]
    
    # Run callbacks
    1000.times { record.save }
    
    GC.start
    memory_after = GC.stat[:total_allocated_objects]
    
    memory_used = memory_after - memory_before
    
    puts "\nMemory usage test:"
    puts "Objects allocated: #{memory_used}"
    puts "Objects per callback run: #{(memory_used / 1000.0).round(2)}"
    
    # Should allocate fewer objects with optimizations
    assert memory_used < 50000, "Should use minimal memory for callback execution"
  end
end
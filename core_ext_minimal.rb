# Minimal core extensions needed for testing

class Class
  unless method_defined?(:subclasses)
    def subclasses
      ObjectSpace.each_object(Class).select { |klass| klass < self }
    end
  end
end

module ActiveSupport
  module Concern
    def self.extended(base) #:nodoc:
      base.instance_variable_set(:@_dependencies, [])
    end

    def append_features(base) #:nodoc:
      if base.instance_variable_defined?(:@_dependencies)
        base.instance_variable_get(:@_dependencies) << self
        false
      else
        return false if base < self
        @_dependencies.each { |dep| base.include(dep) }
        super
        base.extend const_get(:ClassMethods) if const_defined?(:ClassMethods)
        base.class_eval(&@_included_block) if instance_variable_defined?(:@_included_block)
      end
    end

    def included(base = nil, &block)
      if base.nil?
        if instance_variable_defined?(:@_included_block)
          if @_included_block.source_location != block.source_location
            raise ArgumentError, "Cannot define multiple 'included' blocks for a Concern"
          end
        else
          @_included_block = block
        end
      else
        super
      end
    end

    def class_methods(&class_methods_module_definition)
      mod = const_defined?(:ClassMethods, false) ?
        const_get(:ClassMethods) :
        const_set(:ClassMethods, Module.new)

      mod.module_eval(&class_methods_module_definition)
    end
  end
end

# Minimal DescendantsTracker
module ActiveSupport
  module DescendantsTracker
    def self.extended(base)
      # Stub implementation
    end

    def descendants
      subclasses
    end
  end
end
module Spec
  module Runner
    class Specification
      
      @@current_spec = nil
    
      def self.add_listener listener
        @@current_spec.add_listener listener unless @@current_spec.nil?
      end
      
      def initialize(name, opts={}, &block)
        @name = name
        @options = opts
        @block = block
        @listeners = []
      end

      def run(reporter=nil, setup_block=nil, teardown_block=nil, dry_run=false, execution_context=nil)
        reporter.spec_started(@name) unless reporter.nil?
        return reporter.spec_finished(@name) if dry_run
        @@current_spec = self
        execution_context = execution_context || ::Spec::Runner::ExecutionContext.new(self)
        errors = []
        begin
          execution_context.instance_exec(&setup_block) unless setup_block.nil?
          setup_ok = true
          execution_context.instance_exec(&@block)
          spec_ok = true
        rescue => e
          errors << e
        end

        begin
          execution_context.instance_exec(&teardown_block) unless teardown_block.nil?
          teardown_ok = true
        rescue => e
          errors << e
        ensure
          notify_after_teardown errors
          @@current_spec = nil
        end
        
        #TODO - refactor me - PLEASE! (I work, but I'm ugly)
        if what_to_raise = @options[:should_raise]
          if what_to_raise.is_a?(Class)
            error_class = what_to_raise
          elsif what_to_raise.is_a?(Array)
            error_class = what_to_raise[0]
          else
            error_class = Spec::Expectations::ExpectationNotMetError
          end
          if errors.empty?
            errors << Spec::Expectations::ExpectationNotMetError.new
          else
            error_to_remove = errors.detect do |error|
              error.kind_of?(error_class)
            end
            if error_to_remove.nil?
              errors.insert(0,Spec::Expectations::ExpectationNotMetError.new)
            else
              errors.delete(error_to_remove) unless error_to_remove.nil?
            end
          end
        end
        
        reporter.spec_finished(@name, errors.first, failure_location(setup_ok, spec_ok, teardown_ok)) unless reporter.nil?
      end

      def matches_matcher?(matcher)
        matcher.matches? @name 
      end

      def add_listener listener
        @listeners << listener
      end

      def notify_after_teardown errors
        @listeners.each do |listener|
          begin
            listener.spec_finished(self) if listener.respond_to?(:spec_finished)
          rescue => e
            errors << e
          end
        end
      end

      private
      def failure_location(setup_ok, spec_ok, teardown_ok)
        return 'setup' unless setup_ok
        return @name unless spec_ok
        return 'teardown' unless teardown_ok
      end
    end
  end
end
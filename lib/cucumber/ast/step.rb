require 'cucumber/step_definition'
require 'cucumber/core_ext/string'

module Cucumber
  module Ast
    class Step
      ARGUMENT_START = '<'
      ARGUMENT_END  = '>'

      attr_reader :exception
      attr_writer :world, :previous
      attr_accessor :status, :scenario

      def initialize(line, gwt, name, *multiline_args)
        @line, @gwt, @name, @multiline_args = line, gwt, name, multiline_args
      end

      def execute_with_arguments(argument_hash, world, previous, visitor)
        delimited_arguments = delimit_argument_names(argument_hash)
        name                = replace_name_arguments(delimited_arguments)
        multiline_args      = replace_multiline_args_arguments(delimited_arguments)

        # We'll create a new step and execute that
        step = Step.new(-1, @gwt, name, *multiline_args)
        step.scenario = @scenario
        step.world    = world
        step.previous = previous
        step.__send__(:execute, visitor)
      end

      def accept(visitor)
        execute(visitor)
        visitor.visit_step_name(@gwt, @name, @status, @step_invocation, comment_padding)
        @multiline_args.each do |multiline_arg|
          visitor.visit_multiline_arg(multiline_arg, @status)
        end
        visitor.visit_step_exception(@exception) if @exception
      end

      def to_sexp
        [:step, @line, @gwt, @name, *@multiline_args.map{|arg| arg.to_sexp}]
      end

      def at_line?(line)
        @line == line
      end

      def comment_padding
        @scenario.comment_padding(text_length)
      end

      def text_length
        @gwt.jlength + @name.jlength + 2 # Add 2 because steps get indented 2 more than scenarios
      end

      def backtrace_line
        @backtrace_line ||= @scenario.backtrace_line("#{@gwt} #{@name}", @line) unless @scenario.nil?
      end

      def file_line
        @file_line ||= @scenario.file_line(@line) unless @scenario.nil?
      end

      private

      def execute(visitor)
        matched_args = []
        if @status.nil?
          begin
            @step_invocation = visitor.step_invocation(@name, @world)
            matched_args = @step_invocation.matched_args
            if @previous == :passed
              @step_invocation.invoke(*(matched_args + @multiline_args))
              @status = :passed
            else
              @status = :skipped
            end
          rescue StepMom::Undefined
            @status = :undefined
          rescue StepMom::Pending
            @status = :pending
          rescue Exception => exception
            @status = :failed
            @exception = exception
            @exception.backtrace << backtrace_line unless backtrace_line.nil?
          end
        end
        @scenario.step_executed(self) if @scenario
        [@status, matched_args]
      end

      def delimit_argument_names(argument_hash)
        argument_hash.inject({}) { |h,(k,v)| h["#{ARGUMENT_START}#{k}#{ARGUMENT_END}"] = v; h }
      end

      def replace_name_arguments(argument_hash)
        name_with_arguments_replaced = @name
        argument_hash.each do |name, value|
          name_with_arguments_replaced = name_with_arguments_replaced.gsub(name, value)
        end
        name_with_arguments_replaced
      end

      def replace_multiline_args_arguments(arguments)
        @multiline_args.map do |arg|
          arg.arguments_replaced(arguments)
        end
      end
    end
  end
end

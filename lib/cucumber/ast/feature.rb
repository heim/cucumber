module Cucumber
  module Ast
    # Represents the root node of a parsed feature.
    class Feature
      attr_accessor :file
      attr_writer :lines, :features

      def initialize(comment, tags, name, feature_elements)
        @comment, @tags, @name, @feature_elements = comment, tags, name, feature_elements
        feature_elements.each{|feature_element| feature_element.feature = self}
      end

      def accept(visitor)
        visitor.visit_comment(@comment)
        visitor.visit_tags(@tags)
        visitor.visit_feature_name(@name)
        @feature_elements.each do |feature_element|
          visitor.visit_feature_element(feature_element) if @lines.nil? || feature_element.at_any_line?(@lines)
        end
      end

      def step_executed(scenario, step_status)
        @features.step_executed(scenario, step_status) if @features
      end

      def to_sexp
        sexp = [:feature, @name]
        comment = @comment.to_sexp
        sexp += [comment] if comment
        tags = @tags.to_sexp
        sexp += tags if tags.any?
        sexp += @feature_elements.map{|e| e.to_sexp}
        sexp
      end
    end
  end
end
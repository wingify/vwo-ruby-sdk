# Copyright 2019-2021 Wingify Software Pvt. Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative '../enums'

# Utility module for helper math and random functions
class VWO
  module Utils
    module Segment
      GROUPING_PATTERN = /^(.+?)\((.*)\)/
      WILDCARD_PATTERN = /(^\*|^)(.+?)(\*$|$)/
      include VWO::Enums

      # Extracts true values represented in the args, and returns stringified value of it
      #
      # @param [String]             :operator_value                 operand/dsl leaf value
      # @param [String|Number]      :custom_variables_value         custom_variables value
      # @return [[String, String]]  tuple of str value of operator_value, custom_variables_value converted
      #                             into their true types
      def convert_to_true_types(operator_value, custom_variables_value)
        # This is atomic, either both values will be processed or none
        begin
          true_type_operator_value = Kernel::Float(operator_value)
          true_type_custom_variables_value = Kernel::Float(custom_variables_value)
        rescue StandardError => _e
          return operator_value, custom_variables_value
        end
        # Now both are float, So, convert them independently to int type if they are int rather than floats
        true_type_operator_value = true_type_operator_value.to_i if true_type_operator_value == true_type_operator_value.floor

        true_type_custom_variables_value = true_type_custom_variables_value.to_i if true_type_custom_variables_value == true_type_custom_variables_value.floor

        # Convert them back to string and return
        [true_type_operator_value.to_s, true_type_custom_variables_value.to_s]
      end

      # Extract the operand_type, ie. lower, wildcard, regex or equals
      #
      # @param[String]        :operand    string value from leaf_node of dsl
      # @return [[String, String]]        tuple of operand value and operand type
      #
      def separate_operand(operand)
        groups = GROUPING_PATTERN.match(operand)
        return groups[1..2] if groups

        [OperandValueTypesName::EQUALS, operand]
      end

      # Processes the value from the custom_variables_variables
      # @param[String|Number|Boolean|nil]   :custom_variables_value  the custom_variables_value provided inside custom_variables
      #
      # @return [String]                                             stringified value of processed custom_variables_value
      #
      def process_custom_variables_value(custom_variables_value)
        return '' if custom_variables_value.nil?

        if custom_variables_value.is_a?(TrueClass) || custom_variables_value.is_a?(FalseClass)
          custom_variables_value = custom_variables_value ? OperandValuesBooleanTypes::TRUE : OperandValuesBooleanTypes::FALSE
        end
        custom_variables_value.to_s
      end

      # Extracts operand_type and operand_value from the leaf_node/operand
      # @param[String]    :operand                   String value from the leaf_node
      # @return[[String, String]]                    Tuple of defined operand_types and operand_value
      #
      def process_operand_value(operand)
        # Separate the operand type and value inside the bracket

        operand_type_name, operand_value = separate_operand(operand)

        # Enum the operand type, here lower, regex, and equals will be identified
        operand_type =
          begin
            VWO::Enums::OperandValueTypesName.const_get(operand_type_name.upcase)
          rescue StandardError => _e
            nil
          end

        # In case of wildcard, the operand type is further divided into contains, startswith and endswith
        if operand_type_name == OperandValueTypesName::WILDCARD
          starting_star, operand_value, ending_star = WILDCARD_PATTERN.match(operand_value)[1..3]
          operand_type =
            if starting_star.to_s.length > 0 && ending_star.to_s.length > 0
              OperandValueTypes::CONTAINS
            elsif starting_star.to_s.length > 0
              OperandValueTypes::STARTS_WITH
            elsif ending_star.to_s.length > 0
              OperandValueTypes::ENDS_WITH
            else
              OperandValueTypes::EQUALS
            end
        end

        # In case there is an abnormal patter, it would have passed all the above if cases, which means it
        # should be equals, so set the whole operand as operand value and operand type as equals
        if operand_type.nil?
          operand_type = OperandValueTypes::EQUALS
          operand_value = operand
        end
        [operand_type, operand_value]
      end
    end
  end
end

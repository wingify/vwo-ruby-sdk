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

require_relative '../utils/function'
require_relative '../utils/segment'

class VWO
  module Services
    class OperandEvaluator
      include VWO::Utils::Function
      include VWO::Utils::Segment

      # Checks if both values are same after 'down-casing'
      # i.e. case insensitive check
      #
      # @param [String] :operand_value            Leaf value from the segments
      # @param [String] :custom_variables_value   Value from the custom_variables
      #
      # @return [Boolean]
      def lower?(operand_value, custom_variables_value)
        operand_value.downcase == custom_variables_value.downcase
      end

      # Checks if custom_variables_value contains operand_value
      #
      # @param [String] :operand_value            Leaf value from the segments
      # @param [String] :custom_variables_value   Value from the custom_variables
      #
      # @return [Boolean]
      def contains?(operand_value, custom_variables_value)
        custom_variables_value.include?(operand_value)
      end

      # Checks if custom_variables_value ends with operand_value
      #
      # @param [String] :operand_value            Leaf value from the segments
      # @param [String] :custom_variables_value   Value from the custom_variables
      #
      # @return [Boolean]
      def starts_with?(operand_value, custom_variables_value)
        custom_variables_value.end_with?(operand_value)
      end

      # Checks if custom_variables_value starts with operand_value
      #
      # @param [String] :operand_value            Leaf value from the segments
      # @param [String] :custom_variables_value   Value from the custom_variables
      #
      # @return [Boolean]
      def ends_with?(operand_value, custom_variables_value)
        custom_variables_value.start_with?(operand_value)
      end

      # Checks if custom_variables_value matches the regex specified by operand_value
      #
      # @param [String] :operand_value            Leaf value from the segments
      # @param [String] :custom_variables_value   Value from the custom_variables
      #
      # @return [Boolean]
      def regex?(operand_value, custom_variables_value)
        pattern = Regexp.new operand_value
        custom_variables_value =~ pattern
      end

      # Checks if both values are exactly same
      #
      # @param [String] :operand_value            Leaf value from the segments
      # @param [String] :custom_variables_value   Value from the custom_variables
      #
      # @return [Boolean]
      def equals?(operand_value, custom_variables_value)
        custom_variables_value == operand_value
      end

      # Identifies the condition stated in the leaf node and evaluates the result
      #
      # @param [String] :operand_value            Leaf value from the segments
      # @param [String] :custom_variables_value   Value from the custom_variables
      #
      # @return [Boolean]
      def evaluate_custom_variable?(operand, custom_variables)
        # Extract custom_variable_key and custom_variables_value from operand
        operand_key, operand = get_key_value(operand)

        # Retrieve corresponding custom_variable value from custom_variables
        custom_variables_value = custom_variables[operand_key.to_sym]

        # Pre process custom_variable value
        custom_variables_value = process_custom_variables_value(custom_variables_value)

        # Pre process operand value
        operand_type, operand_value = process_operand_value(operand)

        # Process the custom_variables_value and operand_value to make them of same type
        operand_value, custom_variables_value = convert_to_true_types(operand_value, custom_variables_value)

        # Call the self method corresponding to operand_type to evaluate the result
        public_send("#{operand_type}?", operand_value, custom_variables_value)
      end

      def evaluate_user?(operand, custom_variables)
        users = operand.split(',')
        users.each do |user|
          return true if user.strip == custom_variables[:_vwo_user_id]
        end
        false
      end
    end
  end
end

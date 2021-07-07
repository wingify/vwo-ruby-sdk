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

require_relative '../logger'
require_relative '../enums'
require_relative './operand_evaluator'
require_relative '../utils/function'
require_relative '../utils/segment'
require_relative '../utils/validations'

class VWO
  module Services
    class SegmentEvaluator
      include VWO::Enums
      include VWO::Utils::Function
      include VWO::Utils::Segment
      include VWO::Utils::Validations

      # Initializes this class with VWOLogger and OperandEvaluator
      def initialize
        @logger = VWO::Logger.get_instance
        @operand_evaluator = OperandEvaluator.new
      end

      # A parser which recursively evaluates the expression tree represented by dsl,
      # and returns the result
      #
      # @param[Hash]      :dsl                      The segments defined in the campaign
      # @param[Hash]      :custom_variables         Key/value pair of custom_attributes properties
      #
      # @return[Boolean]
      #
      def evaluate_util(dsl, custom_variables)
        operator, sub_dsl = get_key_value(dsl)
        if operator == OperatorTypes::NOT
          !evaluate_util(sub_dsl, custom_variables)
        elsif operator == OperatorTypes::AND
          sub_dsl.all? { |y| evaluate_util(y, custom_variables) }
        elsif operator == OperatorTypes::OR
          sub_dsl.any? { |y| evaluate_util(y, custom_variables) }
        elsif operator == OperandTypes::CUSTOM_VARIABLE
          @operand_evaluator.evaluate_custom_variable?(sub_dsl, custom_variables)
        elsif operator == OperandTypes::USER
          @operand_evaluator.evaluate_user?(sub_dsl, custom_variables)
        end
      end

      # Evaluates the custom_variables passed against the pre-segmentation condition defined
      # in the corresponding campaign.
      #
      # @param[String]                  :campaign_key         Running_campaign's key
      # @param[String]                  :user_id              Unique user identifier
      # @param[Hash]                    :dsl                  Segments provided in the settings_file
      # @param[Hash]                    :custom_variables     Custom variables provided in the apis
      #
      # @return[Boolean]                true if user passed pre-segmentation, else false
      #
      def evaluate(campaign_key, user_id, dsl, custom_variables)
        result = evaluate_util(dsl, custom_variables) if valid_value?(dsl)
        result
      rescue StandardError => e
        @logger.log(
          LogLevelEnum::ERROR,
          format(
            LogMessageEnum::ErrorMessages::SEGMENTATION_ERROR,
            file: FileNameEnum::SegmentEvaluator,
            user_id: user_id,
            campaign_key: campaign_key,
            custom_variables: custom_variables,
            error_message: e
          )
        )
        false
      end
    end
  end
end

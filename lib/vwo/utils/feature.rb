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
require_relative '../constants'

# Utility module for helper math and random functions
class VWO
  module Utils
    module Feature
      include VWO::CONSTANTS
      include VWO::Enums

      # Returns type casted value to given value type if possible.
      # @param[Number|String|Boolean]       :value              Value to type cast
      # @param[Type]                        :variable_type      Type to which value needs to be casted
      # @return[any]                                            Type casted value if value can be type-casted
      def get_type_casted_feature_value(value, variable_type)
        # Check if type(value) is already equal to required variable_type
        return value if RUBY_VARIABLE_TYPES[variable_type].include?(value.class)

        return value.to_s if variable_type == VariableTypes::STRING

        return value.to_i if variable_type == VariableTypes::INTEGER

        return value.to_f if variable_type == VariableTypes::DOUBLE

        return !value || value == 0 ? false : true if variable_type == VariableTypes.BOOLEAN
      rescue StandardError => _e
        VWO::Logger.get_instance.log(
          LogLevelEnum::ERROR,
          format(
            LogMessageEnum::ErrorMessages::UNABLE_TO_TYPE_CAST,
            file: FileNameEnum::FeatureUtil,
            value: value,
            variable_type: variable_type,
            of_type: value.class.name
          )
        )
        nil
      end
    end
  end
end

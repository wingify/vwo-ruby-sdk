# Copyright 2019-2025 Wingify Software Pvt. Ltd.
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

require 'json'
require_relative './validations'
require_relative './data_location_manager'
require_relative '../constants'

# Generic utility module
class VWO
  module Utils
    module Utility
      include Validations
      include VWO::Utils
      include VWO::CONSTANTS

      # converting hash with keys as strings into hash with keys as strings
      # @param[Hash]
      # @return[Hash]
      def convert_to_symbol_hash(hash_object)
        hash_object ||= {}
        converted_hash = {}
        hash_object.each do |key, value|
          converted_hash[key.to_sym] = if valid_hash?(value)
                                         convert_to_symbol_hash(value)
                                       else
                                         value
                                       end
        end
        converted_hash
      end

      def remove_sensitive_properties(properties)
        properties.delete('env')
        properties.delete('env'.to_sym)
        JSON.generate(properties)
      end

      def get_url(endpoint)
        DataLocationManager.get_instance.get_data_location + endpoint
      end

      def prepare_push_response(custom_dimension_map, resp, result)
        custom_dimension_map.each do |tag_key, _tag_value|
          result[tag_key] = resp
        end
        result
      end

      def get_variation_identifiers(variation)
        if variation['goal_identifier']
          identifiers = variation['goal_identifier'].split(VWO_DELIMITER)
        else
          variation['goal_identifier'] = ''
          identifiers = []
        end
        identifiers
      end
    end
  end
end

# Copyright 2019 Wingify Software Pvt. Ltd.
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
require 'json-schema'
require_relative '../schemas/settings_file'

class VWO
  module Utils
    module Validations
      # Validates the settings_file
      # @param [Hash]:  JSON object received from VWO server
      #                 must be JSON.
      # @return [Boolean]
      def valid_settings_file?(settings_file)
        settings_file = JSON.parse(settings_file)
        JSON::Validator.validate!(VWO::Schema::SETTINGS_FILE_SCHEMA, settings_file)
      rescue StandardError
        false
      end

      # @return [Boolean]
      def valid_value?(val)
        !val.nil?
      end

      # @return [Boolean]
      def valid_number?(val)
        val.is_a?(Numeric)
      end

      # @return [Boolean]
      def valid_string?(val)
        val.is_a?(String)
      end

      # @return [Boolean]
      def valid_hash?(val)
        val.is_a?(Hash)
      end
    end
  end
end

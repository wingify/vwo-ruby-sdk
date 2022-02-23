# Copyright 2019-2022 Wingify Software Pvt. Ltd.
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
require_relative '../logger'
require_relative '../enums'
require_relative '../constants'

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
        !val.nil? && val != {} && val != []
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

      # @return [Boolean]
      def valid_boolean?(val)
        val.is_a?(TrueClass) || val.is_a?(FalseClass)
      end

      # @return [Boolean]
      def valid_basic_data_type?(val)
        valid_number?(val) || valid_string?(val) || valid_boolean?(val)
      end

      # Validates if the value passed batch_events has correct data type and values or not.
      #
      # Args: batch_events [Hash]: value to be tested
      #
      # @return: [Boolean]: True if all conditions are passed else False
      def is_valid_batch_event_settings(batch_events)
        logger = VWO::Logger.get_instance
        events_per_request = batch_events[:events_per_request]
        request_time_interval = batch_events[:request_time_interval]

        unless events_per_request || request_time_interval
          logger.log(
            VWO::LogLevelEnum::ERROR,
            format(
              VWO::LogMessageEnum::ErrorMessages::EVENT_BATCHING_INSUFFICIENT,
              file: VWO::FileNameEnum::ValidateUtil
            )
          )
          return false
        end

        if (request_time_interval && !valid_number?(request_time_interval))
          logger.log(
            VWO::LogLevelEnum::ERROR,
            format(
              VWO::LogMessageEnum::ErrorMessages::REQUEST_TIME_INTERVAL_INVALID,
              file: VWO::FileNameEnum::ValidateUtil
            )
          )
          return false
        end

        if (events_per_request && !valid_number?(events_per_request))
          logger.log(
            VWO::LogLevelEnum::ERROR,
            format(
              VWO::LogMessageEnum::ErrorMessages::EVENTS_PER_REQUEST_INVALID,
              file: VWO::FileNameEnum::ValidateUtil
            )
          )
          return false
        end

        if events_per_request && (events_per_request < VWO::MIN_EVENTS_PER_REQUEST || events_per_request > VWO::MAX_EVENTS_PER_REQUEST)
          logger.log(
            VWO::LogLevelEnum::ERROR,
            format(
              VWO::LogMessageEnum::ErrorMessages::EVENTS_PER_REQUEST_OUT_OF_BOUNDS,
              file: VWO::FileNameEnum::ValidateUtil,
              min_value: VWO::MIN_EVENTS_PER_REQUEST,
              max_value: VWO::MAX_EVENTS_PER_REQUEST
            )
          )
          return false
        end

        if request_time_interval && request_time_interval < VWO::MIN_REQUEST_TIME_INTERVAL
          logger.log(
            VWO::LogLevelEnum::ERROR,
            format(
              VWO::LogMessageEnum::ErrorMessages::REQUEST_TIME_INTERVAL_OUT_OF_BOUNDS,
              file: VWO::FileNameEnum::ValidateUtil,
              min_value: VWO::MIN_REQUEST_TIME_INTERVAL
            )
          )
          return false
        end

        if batch_events.key?(:flushCallback) && !batch_events[:flushCallback].is_a?(Method)
          logger.log(
            VWO::LogLevelEnum::ERROR,
            format(
              VWO::LogMessageEnum::ErrorMessages::FLUSH_CALLBACK_INVALID,
              file: VWO::FileNameEnum::ValidateUtil
            )
          )
          return false
        end
        true
      end
    end
  end
end

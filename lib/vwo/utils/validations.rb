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
require_relative '../enums'
require_relative '../constants'
require_relative './log_message'

class VWO
  module Utils
    module Validations
      include Enums
      include CONSTANTS
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
      #       api_name     [String]: current api name
      #
      # @return: [Boolean]: True if all conditions are passed else False
      def valid_batch_event_settings(batch_events, api_name)
        events_per_request = batch_events[:events_per_request]
        request_time_interval = batch_events[:request_time_interval]

        unless events_per_request || request_time_interval
          invalid_config_log('batch_events', 'object', api_name)
          return false
        end

        if request_time_interval && !valid_number?(request_time_interval)
          invalid_config_log('batch_events', 'object', api_name)
          return false
        end

        if events_per_request && !valid_number?(events_per_request)
          invalid_config_log('batch_events', 'object', api_name)
          return false
        end

        if events_per_request && (events_per_request < VWO::MIN_EVENTS_PER_REQUEST || events_per_request > VWO::MAX_EVENTS_PER_REQUEST)
          invalid_config_log('batch_events', 'object', api_name)
          return false
        end

        if request_time_interval && request_time_interval < VWO::MIN_REQUEST_TIME_INTERVAL
          invalid_config_log('batch_events', 'object', api_name)
          return false
        end

        if batch_events.key?(:flushCallback) && !batch_events[:flushCallback].is_a?(Method)
          invalid_config_log('batch_events', 'object', api_name)
          return false
        end
        true
      end

      def validate_sdk_config?(user_storage, is_development_mode, api_name)
        if is_development_mode
          if [true, false].include? is_development_mode
            valid_config_log('isDevelopmentMode', 'boolean')
          else
            invalid_config_log('isDevelopmentMode', 'boolean', api_name)
            return false
          end
        end

        if user_storage
          if user_storage.is_a?(UserStorage)
            valid_config_log('UserStorageService', 'object')
          else
            invalid_config_log('UserStorageService', 'object', api_name)
            return false
          end
        end
        true
      end

      def valid_config_log(parameter, type)
        Logger.log(
          LogLevelEnum::INFO,
          'CONFIG_PARAMETER_USED',
          {
            '{file}' => VWO::FileNameEnum::VALIDATE_UTIL,
            '{parameter}' => parameter,
            '{type}' => type
          }
        )
      end

      def invalid_config_log(parameter, type, api_name)
        Logger.log(
          LogLevelEnum::ERROR,
          'CONFIG_PARAMETER_INVALID',
          {
            '{file}' => VWO::FileNameEnum::VALIDATE_UTIL,
            '{parameter}' => parameter,
            '{type}' => type,
            '{api}' => api_name
          }
        )
      end

      def valid_goal?(goal, campaign, user_id, goal_identifier, revenue_value)
        if goal.nil? || !goal['id']
          Logger.log(
            LogLevelEnum::ERROR,
            'TRACK_API_GOAL_NOT_FOUND',
            {
              '{file}' => FILE,
              '{goalIdentifier}' => goal_identifier,
              '{userId}' => user_id,
              '{campaignKey}' => campaign['key']
            }
          )
          return false
        elsif goal['type'] == GoalTypes::REVENUE && !valid_value?(revenue_value)
          Logger.log(
            LogLevelEnum::ERROR,
            'TRACK_API_REVENUE_NOT_PASSED_FOR_REVENUE_GOAL',
            {
              '{file}' => FILE,
              '{userId}' => user_id,
              '{goalIdentifier}' => goal_identifier,
              '{campaignKey}' => campaign['key']
            }
          )
          return false
        end
        true
      end
    end

    def valid_campaign_for_track_api?(user_id, campaign_key, campaign_type)
      if campaign_type == CONSTANTS::CampaignTypes::FEATURE_ROLLOUT
        Logger.log(
          LogLevelEnum::ERROR,
          'API_NOT_APPLICABLE',
          {
            '{file}' => FILE,
            '{api}' => ApiMethods::TRACK,
            '{userId}' => user_id,
            '{campaignKey}' => campaign_key,
            '{campaignType}' => campaign_type
          }
        )
        return false
      end
      true
    end

    def valid_track_api_params?(user_id, campaign_key, custom_variables, variation_targeting_variables, goal_type_to_track, goal_identifier)
      unless (valid_string?(campaign_key) || campaign_key.is_a?(Array) || campaign_key.nil?) &&
             valid_string?(user_id) && valid_string?(goal_identifier) &&
             (custom_variables.nil? || valid_hash?(custom_variables)) &&
             (variation_targeting_variables.nil? || valid_hash?(variation_targeting_variables)) && CONSTANTS::GOAL_TYPES.key?(goal_type_to_track)
        # log invalid params
        Logger.log(
          LogLevelEnum::ERROR,
          'API_BAD_PARAMETERS',
          {
            '{file}' => FILE,
            '{api}' => ApiMethods::TRACK
          }
        )
        return false
      end
      true
    end
  end
end

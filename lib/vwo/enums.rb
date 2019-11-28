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

# rubocop:disable Metrics/LineLength

require 'logger'

class VWO
  module Enums
    module FileNameEnum
      VWO_PATH = 'vwo'
      UTIL_PATH = 'vwo/utils'

      VWO = VWO_PATH + '/vwo'
      Bucketer = VWO_PATH + '/core/bucketer'
      VariationDecider = VWO_PATH + '/core/variation_decider'
      EventDispatcher = VWO_PATH + '/services/event_dispatcher'
      Logger = VWO_PATH + '/logger'
      SettingsFileProcessor = VWO_PATH + '/services/settings_file_processor'

      CampaignUtil = UTIL_PATH + '/campaign'
      FunctionUtil = UTIL_PATH + '/function'
      ImpressionUtil = UTIL_PATH + '/impression'
      UuidUtil = UTIL_PATH + '/uuid'
      ValidateUtil = UTIL_PATH + '/validations'
    end

    # Logging Enums
    module LogMessageEnum
      # Debug Messages
      module DebugMessages
        LOG_LEVEL_SET = '(%<file>s): Log level set to %<level>s'
        SET_DEVELOPMENT_MODE = '(%<file>s): DEVELOPMENT mode is ON'
        VALID_CONFIGURATION = '(%<file>s): SDK configuration and account settings are valid.'
        CUSTOM_LOGGER_USED = '(%<file>s): Custom logger used'
        SDK_INITIALIZED = '(%<file>s): SDK properly initialized'
        SETTINGS_FILE_PROCESSED = '(%<file>s): Settings file processed'
        NO_STORED_VARIATION = '(%<file>s): No stored variation for UserId:%<user_id>s for Campaign:%<campaign_key>s found in UserStorageService'
        NO_USER_STORAGE_SERVICE_LOOKUP = '(%<file>s): No UserStorageService to look for stored data'
        NO_USER_STORAGE_SERVICE_SAVE = '(%<file>s): No UserStorageService to save data'
        GETTING_STORED_VARIATION = '(%<file>s): Got stored variation for UserId:%<user_id>s of Campaign:%<campaign_key>s as Variation: %<variation_name>s found in UserStorageService'
        CHECK_USER_ELIGIBILITY_FOR_CAMPAIGN = '(%<file>s): campaign:%<campaign_key>s having traffic allocation:%<traffic_allocation>s assigned value:%<traffic_allocation>s to userId:%<user_id>s'
        USER_HASH_BUCKET_VALUE = '(%<file>s): userId:%<user_id>s having hash:%<hash_value>s got bucketValue:%<bucket_value>s'
        VARIATION_HASH_BUCKET_VALUE = '(%<file>s): userId:%<user_id>s for campaign:%<campaign_key>s having percent traffic:%<percent_traffic>s got hash-value:%<hash_value>s and bucket value:%<bucket_value>s'
        IMPRESSION_FAILED = '(%<file>s): userId:%<user_id>s for campaign:%<campaign_key>s got variationName:%<variation_name>s inside method:%<method>s'
        USER_NOT_PART_OF_CAMPAIGN = '(%<file>s): userId:%<user_id>s for campaign:%<campaign_key>s did not become part of campaign method:%<method>s'
        UUID_FOR_USER = '(%<file>s): Uuid generated for userId:%<user_id>s and accountId:%<account_id>s is %<desired_uuid>s'
        IMPRESSION_FOR_TRACK_USER = '(%<file>s): Impression built for track-user - %<properties>s'
        IMPRESSION_FOR_TRACK_GOAL = '(%<file>s): Impression built for track-goal - %<properties>s'
        GOT_VARIATION_FOR_USER = '(%<file>s): userId:%<user_id>s for campaign:%<campaign_key>s got variationName:%<variation_name>s'
      end

      # Info Messages
      module InfoMessages
        VARIATION_RANGE_ALLOCATION = '(%<file>s): Campaign:%<campaign_key>s having variations:%<variation_name>s with weight:%<variation_weight>s got range as: ( %<start>s - %<end>s ))'
        VARIATION_ALLOCATED = '(%<file>s): UserId:%<user_id>s of Campaign:%<campaign_key>s got variation: %<variation_name>s'
        LOOKING_UP_USER_STORAGE_SERVICE = '(%<file>s): Looked into UserStorageService for userId:%<user_id>s %<status>s'
        SAVING_DATA_USER_STORAGE_SERVICE = '(%<file>s): Saving into UserStorageService for userId:%<user_id>s successful'
        GOT_STORED_VARIATION = '(%<file>s): Got stored variation:%<variation_name>s of campaign:%<campaign_key>s for userId:%<user_id>s from UserStorageService'
        NO_VARIATION_ALLOCATED = '(%<file>s): UserId:%<user_id>s of Campaign:%<campaign_key>s did not get any variation'
        USER_ELIGIBILITY_FOR_CAMPAIGN = '(%<file>s): Is userId:%<user_id>s part of campaign? %<is_user_part>s'
        AUDIENCE_CONDITION_NOT_MET = '(%<file>s): userId:%<user_id>s does not become part of campaign because of not meeting audience conditions'
        GOT_VARIATION_FOR_USER = '(%<file>s): userId:%<user_id>s for campaign:%<campaign_key>s got variationName:%<variation_name>s'
        USER_GOT_NO_VARIATION = '(%<file>s): userId:%<user_id>s for campaign:%<campaign_key>s did not allot any variation'
        IMPRESSION_SUCCESS = '(%<file>s): Impression event - %<end_point>s was successfully received by VWO having main keys: accountId:%<account_id>s userId:%<user_id>s campaignId:%<campaign_id>s and variationId:%<variation_id>s'
        INVALID_VARIATION_KEY = '(%<file>s): Variation was not assigned to userId:%<user_id>s for campaign:%<campaign_key>s'
      end

      # Warning Messages
      module WarningMessages; end

      # Error Messages
      module ErrorMessages
        SETTINGS_FILE_CORRUPTED = '(%<file>s): Settings file is corrupted. Please contact VWO Support for help.'
        ACTIVATE_API_MISSING_PARAMS = '(%<file>s): "activate" API got bad parameters. It expects campaignTestKey(String) as first and userId(String) as second argument'
        ACTIVATE_API_CONFIG_CORRUPTED = '(%<file>s): "activate" API has corrupted configuration'
        GET_VARIATION_NAME_API_MISSING_PARAMS = '(%<file>s): "getVariation" API got bad parameters. It expects campaignTestKey(String) as first and userId(String) as second argument'
        GET_VARIATION_API_CONFIG_CORRUPTED = '(%<file>s): "getVariation" API has corrupted configuration'
        TRACK_API_MISSING_PARAMS = '(%<file>s): "track" API got bad parameters. It expects campaignTestKey(String) as first userId(String) as second and goalIdentifier(String/Number) as third argument. Fourth is revenueValue(Float/Number/String) and is required for revenue goal only.'
        TRACK_API_CONFIG_CORRUPTED = '(%<file>s): "track" API has corrupted configuration'
        TRACK_API_GOAL_NOT_FOUND = '(%<file>s): Goal:%<goal_identifier>s not found for campaign:%<campaign_key>s and userId:%<user_id>s'
        TRACK_API_REVENUE_NOT_PASSED_FOR_REVENUE_GOAL = '(%<file>s): Revenue value should be passed for revenue goal:%<goal_identifier>s for campaign:%<campaign_key>s and userId:%<user_id>s'
        TRACK_API_VARIATION_NOT_FOUND = '(%<file>s): Variation not found for campaign:%<campaign_key>s and userId:%<user_id>s'
        CAMPAIGN_NOT_RUNNING = '(%<file>s): API used:%<api>s - Campaign:%<campaign_key>s is not RUNNING. Please verify from VWO App'
        LOOK_UP_USER_STORAGE_SERVICE_FAILED = '(%<file>s): Looking data from UserStorageService failed for userId:%<user_id>s'
        SAVE_USER_STORAGE_SERVICE_FAILED = '(%<file>s): Saving data into UserStorageService failed for userId:%<user_id>s'
        INVALID_CAMPAIGN = '(%<file>s): Invalid campaign passed to %<method>s of this file'
        INVALID_USER_ID = '(%<file>s): Invalid userId:%<user_id>s passed to %<method>s of this file'
        IMPRESSION_FAILED = '(%<file>s): Impression event could not be sent to VWO - %<end_point>s'
        CUSTOM_LOGGER_MISCONFIGURED = '(%<file>s): Custom logger is provided but seems to have mis-configured. %<extra_info>s Please check the API Docs. Using default logger.'
      end
    end

    module LogLevelEnum
      INFO = ::Logger::INFO
      DEBUG = ::Logger::DEBUG
      WARNING = ::Logger::WARN
      ERROR = ::Logger::ERROR
    end
  end
end
# rubocop:enable Metrics/LineLength

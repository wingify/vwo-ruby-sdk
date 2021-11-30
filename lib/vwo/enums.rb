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

# rubocop:disable Metrics/LineLength

require 'logger'

class VWO
  module Enums
    module OperandValueTypesName
      REGEX = 'regex'
      WILDCARD = 'wildcard'
      LOWER = 'lower'
      EQUALS = 'equals'
    end

    module OperandValueTypes
      LOWER = 'lower'
      CONTAINS = 'contains'
      STARTS_WITH = 'starts_with'
      ENDS_WITH = 'ends_with'
      REGEX = 'regex'
      EQUALS = 'equals'
    end

    module OperatorTypes
      AND = 'and'
      OR = 'or'
      NOT = 'not'
    end

    module OperandTypes
      CUSTOM_VARIABLE = 'custom_variable'
      USER = 'user'
    end

    module OperandValuesBooleanTypes
      TRUE = 'true'
      FALSE = 'false'
    end

    module StatusEnum
      PASSED = 'passed'
      FAILED = 'failed'
    end

    module SegmentationTypeEnum
      WHITELISTING = 'whitelisting'
      PRE_SEGMENTATION = 'pre-segmentation'
    end

    module FileNameEnum
      VWO_PATH = 'vwo'
      UTIL_PATH = 'vwo/utils'

      VWO = VWO_PATH + '/vwo'
      Bucketer = VWO_PATH + '/core/bucketer'
      VariationDecider = VWO_PATH + '/core/variation_decider'
      EventDispatcher = VWO_PATH + '/services/event_dispatcher'
      SegmentEvaluator = VWO_PATH + '/services/segment_evaluator'
      Logger = VWO_PATH + '/logger'
      SettingsFileProcessor = VWO_PATH + '/services/settings_file_processor'
      BatchEventsQueue = VWO_PATH + '/services/batch_events_queue'
      BatchEventsDispatcher = VWO_PATH + '/services/batch_events_dispatcher'

      CampaignUtil = UTIL_PATH + '/campaign'
      FunctionUtil = UTIL_PATH + '/function'
      FeatureUtil = UTIL_PATH + '/feature'
      ImpressionUtil = UTIL_PATH + '/impression'
      UuidUtil = UTIL_PATH + '/uuid'
      ValidateUtil = UTIL_PATH + '/validations'
      CustomDimensionsUtil = UTIL_PATH + '/custom_dimensions_util'
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
        SEGMENTATION_STATUS = '(%<file>s): In API: %<api_name>s, for UserId:%<user_id>s of campaign:%<campaign_key>s  with variables:%<custom_variables>s %<status>s %<segmentation_type>s %<variation_name>s'
        PARAMS_FOR_PUSH_CALL = '(%<file>s): Params for push call - %<properties>s'
        CAMPAIGN_NOT_ACTIVATED = '(%<file>s): Campaign:%<campaign_key>s for User ID:%<user_id>s is not yet activated for API:%<api_name>s. Use activate API to activate A/B test or isFeatureEnabled API to activate Feature Test.'
        BATCH_EVENT_LIMIT_EXCEEDED = '(%<file>s): Impression event - %<end_point>s failed due to exceeding payload size. Parameter eventsPerRequest in batchEvents config in launch API has value:%<eventsPerRequest>s for accountId:%<accountId>s. Please read the official documentation for knowing the size limits.'
        BULK_NOT_PROCESSED = "(%<file>s): Batch events couldn't be received by VWO. Calling Flush Callback with error and data."
        BEFORE_FLUSHING = '(%<file>s): Flushing events queue %<manually>s having %<length>s events %<timer>s queue summary: %<queue_metadata>s'
        EVENT_BATCHING_INSUFFICIENT = '(%<file>s): %<key>s not provided, assigning default value'
        GOT_ELIGIBLE_CAMPAIGNS = "(%<file>s): Campaigns:%<eligible_campaigns_key>s are eligible, %<ineligible_campaigns_log_text>s are ineligible from the Group:%<group_name>s for the User ID:%<user_id>s"
      end

      # Info Messages
      module InfoMessages
        VARIATION_RANGE_ALLOCATION = '(%<file>s): Campaign:%<campaign_key>s having variations:%<variation_name>s with weight:%<variation_weight>s got range as: ( %<start>s - %<end>s ))'
        VARIATION_ALLOCATED = '(%<file>s): UserId:%<user_id>s of Campaign:%<campaign_key>s type: %<campaign_type>s got variation: %<variation_name>s'
        LOOKING_UP_USER_STORAGE_SERVICE = '(%<file>s): Looked into UserStorageService for userId:%<user_id>s %<status>s'
        SAVING_DATA_USER_STORAGE_SERVICE = '(%<file>s): Saving into UserStorageService for userId:%<user_id>s successful'
        GOT_STORED_VARIATION = '(%<file>s): Got stored variation:%<variation_name>s of campaign:%<campaign_key>s for userId:%<user_id>s from UserStorageService'
        NO_VARIATION_ALLOCATED = '(%<file>s): UserId:%<user_id>s of Campaign:%<campaign_key>s did not get any variation'
        USER_ELIGIBILITY_FOR_CAMPAIGN = '(%<file>s): Is userId:%<user_id>s part of campaign? %<is_user_part>s'
        AUDIENCE_CONDITION_NOT_MET = '(%<file>s): userId:%<user_id>s does not become part of campaign because of not meeting audience conditions'
        GOT_VARIATION_FOR_USER = '(%<file>s): userId:%<user_id>s for campaign:%<campaign_key>s got variationName:%<variation_name>s'
        USER_GOT_NO_VARIATION = '(%<file>s): userId:%<user_id>s for campaign:%<campaign_key>s did not allot any variation'
        IMPRESSION_SUCCESS = '(%<file>s): Impression event - %<end_point>s was successfully received by VWO having main keys: accountId:%<account_id>s campaignId:%<campaign_id>s and variationId:%<variation_id>s'
        MAIN_KEYS_FOR_IMPRESSION = '(%<file>s): Having main keys: accountId:%<account_id>s campaignId:%<campaign_id>s and variationId:%<variation_id>s}'
        MAIN_KEYS_FOR_PUSH_API = '(%<file>s): Having main keys: accountId:%<account_id>s u:%<u>s and tags:%<tags>s}'
        INVALID_VARIATION_KEY = '(%<file>s): Variation was not assigned to userId:%<user_id>s for campaign:%<campaign_key>s'

        USER_IN_FEATURE_ROLLOUT = '(%<file>s): User ID:%<user_id>s is in feature rollout:%<campaign_key>s'
        USER_NOT_IN_FEATURE_ROLLOUT = '(%<file>s): User ID:%<user_id>s is NOT in feature rollout:%<campaign_key>s'
        FEATURE_ENABLED_FOR_USER = '(%<file>s): In API: %<api_name>s Feature having feature-key:%<feature_key>s for user ID:%<user_id>s is enabled'
        FEATURE_NOT_ENABLED_FOR_USER = '(%<file>s): In API: %<api_name>s Feature having feature-key:%<feature_key>s for user ID:%<user_id>s is not enabled'

        VARIABLE_FOUND = '(%<file>s): In API: %<api_name>s Value for variable:%<variable_key>s of campaign:%<campaign_key>s and campaign type: %<campaign_type>s is:%<variable_value>s for user:%<user_id>s'

        USER_PASSED_SEGMENTATION = '(%<file>s): UserId:%<user_id>s of campaign:%<campaign_key>s with custom_variables:%<custom_variables>s passed segmentation'
        USER_FAILED_SEGMENTATION = '(%<file>s): UserId:%<user_id>s of campaign:%<campaign_key>s with custom_variables:%<custom_variables>s failed segmentation'

        NO_CUSTOM_VARIABLES = '(%<file>s): In API: %<api_name>s, for UserId:%<user_id>s customVariables are not passed for campaign:%<campaign_key>s and campaign has pre-segmentation'
        SKIPPING_SEGMENTATION = '(%<file>s): In API: %<api_name>s, Skipping segmentation:%<variation>s for UserId:%<user_id>s as no valid segments found in campaign:%<campaign_key>s'

        SEGMENTATION_STATUS = '(%<file>s): In API: %<api_name>s, for UserId:%<user_id>s of campaign:%<campaign_key>s  with variables:%<custom_variables>s %<status>s %<segmentation_type>s %<variation_name>s'
        WHITELISTING_SKIPPED = '(%<file>s): In API: %<api_name>s, Skipping whitelisting for UserId:%<user_id>s of campaign:%<campaign_key>s'
        SETTINGS_NOT_UPDATED = '(%<file>s): Settings-file fetched are same as earlier fetched settings'
        SETTINGS_FILE_UPDATED = '(%<file>s): %<api_name>s vwo_sdk_instance is updated with the latest settings_file'
        CAMPAIGN_NOT_ACTIVATED = '(%<file>s): Activate the campaign:%<campaign_key>s for User ID:%<user_id>s to %<reason>s.'
        GOAL_ALREADY_TRACKED = '(%<file>s): Goal:%<goal_identifier>s of Campaign:%<campaign_key>s for User ID:%<user_id>s has already been tracked earlier. Skipping now'
        USER_ALREADY_TRACKED = '(%<file>s): User ID:%<user_id>s for Campaign:%<campaign_key>s has already been tracked earlier for "%<api_name>s" API. Skipping now'
        API_CALLED = '(%<file>s): API: %<api_name>s called for UserId:%<user_id>s'
        BULK_IMPRESSION_SUCCESS = '(%<file>s): Impression event - %<end_point>s was successfully received by VWO having accountId:%<a>s'
        AFTER_FLUSHING = '(%<file>s): Events queue having %<length>s events has been flushed %<manually>s queue summary: %<queue_metadata>s'
        GOT_WINNER_CAMPAIGN = "(%<file>s): Campaign:%<campaign_key>s is selected from the mutually exclusive group:%<group_name>s for the User ID:%<user_id>s"
        GOT_ELIGIBLE_CAMPAIGNS = "(%<file>s): Got %<no_of_eligible_campaigns>s eligible winners out of %<no_of_group_campaigns>s from the Group:%<group_name>s and for User ID:%<user_id>s"
        CALLED_CAMPAIGN_NOT_WINNER = "(%<file>s): Campaign:%<campaign_key>s does not qualify from the mutually exclusive group:%<group_name>s for User ID:%<user_id>s"
        OTHER_CAMPAIGN_SATISFIES_WHITELISTING_OR_STORAGE = "(%<file>s): Campaign:%<campaign_key>s of Group:%<group_name>s satisfies %<type>s for User ID:%<user_id>s"
      end

      # Warning Messages
      module WarningMessages; end

      # Error Messages
      module ErrorMessages
        SETTINGS_FILE_CORRUPTED = '(%<file>s): Settings file is corrupted. Please contact VWO Support for help.'
        ACTIVATE_API_MISSING_PARAMS = '(%<file>s): %<api_name>s API got bad parameters. It expects campaignTestKey(String) as first and userId(String) as second argument, customVariables(Hash) can be passed via options for pre-segmentation'
        API_CONFIG_CORRUPTED = '(%<file>s): %<api_name>s API has corrupted configuration'
        GET_VARIATION_NAME_API_INVALID_PARAMS = '(%<file>s): %<api_name>s API got bad parameters. It expects campaignTestKey(String) as first and userId(String) as second argument, customVariables(Hash) can be passed via options for pre-segmentation'
        GET_VARIATION_API_CONFIG_CORRUPTED = '(%<file>s): "getVariation" API has corrupted configuration'
        TRACK_API_INVALID_PARAMS = '(%<file>s): %<api_name>s API got bad parameters. It expects campaignTestKey(Nil/String/Array) as first userId(String) as second and goalIdentifier(String/Number) as third argument. Fourth is revenueValue(Float/Number/String) and is required for revenue goal only. customVariables(Hash) can be passed via options for pre-segmentation'
        TRACK_API_CONFIG_CORRUPTED = '(%<file>s): "track" API has corrupted configuration'
        TRACK_API_GOAL_NOT_FOUND = '(%<file>s): Goal:%<goal_identifier>s not found for campaign:%<campaign_key>s and userId:%<user_id>s'
        TRACK_API_REVENUE_NOT_PASSED_FOR_REVENUE_GOAL = '(%<file>s): Revenue value should be passed for revenue goal:%<goal_identifier>s for campaign:%<campaign_key>s and userId:%<user_id>s'
        TRACK_API_VARIATION_NOT_FOUND = '(%<file>s): Variation not found for campaign:%<campaign_key>s and userId:%<user_id>s'
        CAMPAIGN_NOT_RUNNING = '(%<file>s): API used:%<api_name>s - Campaign:%<campaign_key>s is not RUNNING. Please verify from VWO App'
        LOOK_UP_USER_STORAGE_SERVICE_FAILED = '(%<file>s): Looking data from UserStorageService failed for userId:%<user_id>s'
        SAVE_USER_STORAGE_SERVICE_FAILED = '(%<file>s): Saving data into UserStorageService failed for userId:%<user_id>s'
        INVALID_CAMPAIGN = '(%<file>s): Invalid campaign passed to %<method>s of this file'
        INVALID_USER_ID = '(%<file>s): Invalid userId:%<user_id>s passed to %<method>s of this file'
        IMPRESSION_FAILED = '(%<file>s): Impression event could not be sent to VWO - %<end_point>s'
        CUSTOM_LOGGER_MISCONFIGURED = '(%<file>s): Custom logger is provided but seems to have mis-configured. %<extra_info>s Please check the API Docs. Using default logger.'
        INVALID_API = '(%<file>s): %<api_name>s API is not valid for user ID: %<user_id>s in campaign ID: %<campaign_key>s having campaign type: %<campaign_type>s.'
        IS_FEATURE_ENABLED_API_INVALID_PARAMS = '(%<file>s): %<api_name>s API got bad parameters. It expects campaign_key(String) as first and user_id(String) as second argument, customVariables(dict) can be passed via options for pre-segmentation'
        GET_FEATURE_VARIABLE_VALUE_API_INVALID_PARAMS = '(%<file>s): "get_feature_variable" API got bad parameters. It expects campaign_key(String) as first, variable_key(string) as second and user_id(String) as third argument, customVariables(dict) can be passed via options for pre-segmentation'

        VARIABLE_NOT_FOUND = '(%<file>s): In API: %<api_name>s Variable %<variable_key>s not found for campaign %<campaign_key>s and type %<campaign_type>s for user ID %<user_id>s'
        UNABLE_TO_TYPE_CAST = '(%<file>s): Unable to typecast value: %<value>s of type: %<of_type>s to type: %<variable_type>s.'

        USER_NOT_IN_CAMPAIGN = '(%<file>s): userId:%<user_id>s did not become part of campaign:%<campaign_key>s and campaign type:%<campaign_type>s'
        API_NOT_WORKING = '(%<file>s): API: %<api_name>s not working, exception caught: %<exception>s. Please contact VWO Support for help.'

        SEGMENTATION_ERROR = '(%<file>s): Error while segmenting the UserId:%<user_id>s of campaign:%<campaign_key>s with custom_variables:%<custom_variables>s. Error message: %<error_message>s'

        PUSH_API_INVALID_PARAMS = '(%<file>s): %<api_name>s API got bad parameters. It expects tag_key(String) as first and tag_value(String) as second argument and user_id(String) as third argument'
        TAG_VALUE_LENGTH_EXCEEDED = '(%<file>s): In API: %<api_name>s, the length of tag_value:%<tag_value>s and userID: %<user_id>s can not be greater than 255'
        TAG_KEY_LENGTH_EXCEEDED = '(%<file>s): In API: %<api_name>s, the length of tag_key:%<tag_key>s and userID: %<user_id>s can not be greater than 255'
        TRACK_API_MISSING_PARAMS = '(%<file>s): "track" API got bad parameters. It expects campaignKey(null/String/array) as first, userId(String/Number) as second and goalIdentifier (string) as third argument. options is revenueValue(Float/Number/String) and is required for revenue goal only.'
        NO_CAMPAIGN_FOUND = '(%<file>s): No campaign found for goal_identifier:%<goal_identifier>s. Please verify from VWO app.'
        INVALID_TRACK_RETURNING_USER_VALUE  = '(%<file>s): should_track_returning_user should be boolean'
        INVALID_GOAL_TYPE = '(%<file>s): goal_type_to_track should be certain strings'
        EVENT_BATCHING_NOT_OBJECT = '(%<file>s): Batch events settings are not of type object.'
        EVENTS_PER_REQUEST_INVALID = '(%<file>s): events_per_request should be an integer'
        REQUEST_TIME_INTERVAL_INVALID = '(%<file>s): request_time_interval should be a number'
        EVENTS_PER_REQUEST_OUT_OF_BOUNDS = '(%<file>s): events_per_request should be >= %<min_value>s and <= %<max_value>s'
        REQUEST_TIME_INTERVAL_OUT_OF_BOUNDS = '(%<file>s): request_time_interval should be >= %<min_value>s'
        FLUSH_CALLBACK_INVALID = '(%<file>s): flush_callback is not callable'
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

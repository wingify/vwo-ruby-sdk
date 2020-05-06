# Copyright 2019-2020 Wingify Software Pvt. Ltd.
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

require 'logger'

require_relative 'vwo/services/settings_file_manager'
require_relative 'vwo/services/event_dispatcher'
require_relative 'vwo/services/settings_file_processor'
require_relative 'vwo/logger'
require_relative 'vwo/enums'
require_relative 'vwo/utils/campaign'
require_relative 'vwo/utils/impression'
require_relative 'vwo/utils/feature'
require_relative 'vwo/utils/custom_dimensions'
require_relative 'vwo/constants'
require_relative 'vwo/core/variation_decider'

# VWO main file
class VWO
  attr_accessor :is_instance_valid, :logger

  include Enums
  include Utils::Validations
  include Utils::Feature
  include Utils::CustomDimensions
  include Utils::Campaign
  include Utils::Impression
  include CONSTANTS

  FILE = FileNameEnum::VWO

  # Initializes and expose APIs
  #
  # @param[Numeric|String]  :account_id             Account Id in VWO
  # @param[String]          :sdk_key                Unique sdk key for user
  # @param[Object]          :logger                 Optional - should have log method defined
  # @param[Object]          :user_storage           Optional - to store and manage user data mapping
  # @param[Boolean]         :is_development_mode    To specify whether the request
  #                                                 to our server should be sent or not.
  # @param[String]          :settings_file           Settings-file data

  def initialize(
    account_id,
    sdk_key,
    logger = nil,
    user_storage = nil,
    is_development_mode = false,
    settings_file = nil,
    options = {}
  )
    @account_id = account_id
    @sdk_key = sdk_key
    @user_storage = user_storage
    @is_development_mode = is_development_mode
    @logger = VWO::Logger.get_instance(logger)
    @logger.instance.level = options[:log_level] if (0..5).include?(options[:log_level])

    unless valid_settings_file?(get_settings(settings_file))
      @logger.log(
        LogLevelEnum::ERROR,
        format(LogMessageEnum::ErrorMessages::SETTINGS_FILE_CORRUPTED, file: FILE)
      )
      @is_instance_valid = false
      return
    end
    @is_instance_valid = true
    @config = VWO::Services::SettingsFileProcessor.new(get_settings)

    @logger.log(
      LogLevelEnum::DEBUG,
      format(
        LogMessageEnum::DebugMessages::VALID_CONFIGURATION,
        file: FILE
      )
    )

    # Process the settings file
    @config.process_settings_file
    @settings_file = @config.get_settings_file

    # Assign VariationDecider to VWO
    @variation_decider = VWO::Core::VariationDecider.new(@settings_file, user_storage)

    if is_development_mode
      @logger.log(
        LogLevelEnum::DEBUG,
        format(
          LogMessageEnum::DebugMessages::SET_DEVELOPMENT_MODE,
          file: FILE
        )
      )
    end
    # Assign event dispatcher
    @event_dispatcher = VWO::Services::EventDispatcher.new(is_development_mode)

    # Successfully initialized VWO SDK
    @logger.log(
      LogLevelEnum::DEBUG,
      format(
        LogMessageEnum::DebugMessages::SDK_INITIALIZED,
        file: FILE
      )
    )
  end

  # Public Methods

  # VWO get_settings method to get settings for a particular account_id
  def get_settings(settings_file = nil)
    @settings ||=
      settings_file || VWO::Services::SettingsFileManager.new(@account_id, @sdk_key).get_settings_file
    @settings
  end

  # This API method: Gets the variation assigned for the user
  # For the campaign and send the metrics to VWO server
  #
  # 1. Validates the arguments being passed
  # 2. Checks if user is eligible to get bucketed into the campaign,
  # 3. Assigns the deterministic variation to the user(based on userId),
  #    If user becomes part of campaign
  #    If UserStorage is used, it will look into it for the
  #    Variation and if found, no further processing is done
  # 4. Sends an impression call to VWO server to track user
  #
  # @param[String]            :campaign_key  Unique campaign key
  # @param[String]            :user_id            ID assigned to a user
  # @param[Hash]                :options                  Options for custom variables required for segmentation
  # @return[String|None]                          If variation is assigned then variation-name
  #                                               otherwise null in case of user not becoming part

  def activate(campaign_key, user_id, options = {})
    # Retrieve custom variables
    custom_variables = options['custom_variables'] || options[:custom_variables]
    variation_targeting_variables = options['variation_targeting_variables'] || options[:variation_targeting_variables]

    # Validate input parameters
    unless valid_string?(campaign_key) && valid_string?(user_id) && (custom_variables.nil? || valid_hash?(custom_variables)) &&
           (variation_targeting_variables.nil? || valid_hash?(variation_targeting_variables))
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::ACTIVATE_API_MISSING_PARAMS,
          api_name: ApiMethods::ACTIVATE,
          file: FILE
        )
      )
      return
    end

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::API_CONFIG_CORRUPTED,
          file: FILE,
          api_name: ApiMethods::ACTIVATE
        )
      )
      return
    end

    # Get the campaign settings
    campaign = get_campaign(@settings_file, campaign_key)

    # Validate campaign
    unless campaign && campaign['status'] == STATUS_RUNNING
      # Log Campaign as invalid
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::CAMPAIGN_NOT_RUNNING,
          file: FILE,
          campaign_key: campaign_key,
          api_name: ApiMethods::ACTIVATE
        )
      )
      return
    end

    # Get campaign type
    campaign_type = campaign['type']

    # Validate valid api call
    if campaign_type != CampaignTypes::VISUAL_AB
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::INVALID_API,
          file: FILE,
          api_name: ApiMethods::ACTIVATE,
          user_id: user_id,
          campaign_key: campaign_key,
          campaign_type: campaign_type
        )
      )
      return
    end

    # Once the matching RUNNING campaign is found, assign the
    # deterministic variation to the user_id provided

    variation = @variation_decider.get_variation(
      user_id,
      campaign,
      ApiMethods::ACTIVATE,
      campaign_key,
      custom_variables,
      variation_targeting_variables
    )

    # Check if variation_name has been assigned
    if variation.nil?
      @logger.log(
        LogLevelEnum::INFO,
        format(
          LogMessageEnum::InfoMessages::INVALID_VARIATION_KEY,
          file: FILE,
          user_id: user_id,
          campaign_key: campaign_key
        )
      )
      return
    end

    # Variation found, dispatch it to server
    impression = create_impression(
      @settings_file,
      campaign['id'],
      variation['id'],
      user_id
    )
    @event_dispatcher.dispatch(impression)
    variation['name']
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      format(
        LogMessageEnum::ErrorMessages::API_NOT_WORKING,
        file: FILE,
        api_name: ApiMethods::ACTIVATE,
        exception: e
      )
    )
    nil
  end

  # This API method: Gets the variation name assigned for the
  # user for the campaign
  #
  # 1. Validates the arguments being passed
  # 2. Checks if user is eligible to get bucketed into the campaign,
  # 3. Assigns the deterministic variation to the user(based on user_id),
  #    If user becomes part of campaign
  #    If UserStorage is used, it will look into it for the
  #    variation and if found, no further processing is done
  #
  # @param[String]              :campaign_key             Unique campaign key
  # @param[String]              :user_id                  ID assigned to a user
  # @param[Hash]                :options                  Options for custom variables required for segmentation
  #
  # @@return[String|Nil]                                  If variation is assigned then variation-name
  #                                                       Otherwise null in case of user not becoming part
  #
  def get_variation_name(campaign_key, user_id, options = {})
    # Retrieve custom variables
    custom_variables = options['custom_variables'] || options[:custom_variables]
    variation_targeting_variables = options['variation_targeting_variables'] || options[:variation_targeting_variables]

    # Validate input parameters
    unless valid_string?(campaign_key) && valid_string?(user_id) && (custom_variables.nil? || valid_hash?(custom_variables)) &&
           (variation_targeting_variables.nil? || valid_hash?(variation_targeting_variables))
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::GET_VARIATION_NAME_API_INVALID_PARAMS,
          api_name: ApiMethods::GET_VARIATION_NAME,
          file: FILE
        )
      )
      return
    end
    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::API_CONFIG_CORRUPTED,
          file: FILE,
          api_name: ApiMethods::GET_VARIATION_NAME
        )
      )
      return
    end

    # Get the campaign settings
    campaign = get_campaign(@settings_file, campaign_key)

    # Validate campaign
    if campaign.nil? || campaign['status'] != STATUS_RUNNING
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::CAMPAIGN_NOT_RUNNING,
          file: FILE,
          campaign_key: campaign_key,
          api_name: ApiMethods::GET_VARIATION_NAME
        )
      )
      return
    end

    campaign_type = campaign['type']

    if campaign_type == CampaignTypes::FEATURE_ROLLOUT
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages.INVALID_API,
          file: FILE,
          api_name: ApiMethods::GET_VARIATION_NAME,
          user_id: user_id,
          campaign_key: campaign_key,
          campaign_type: campaign_type
        )
      )
      return
    end

    variation = @variation_decider.get_variation(user_id, campaign, ApiMethods::GET_VARIATION_NAME, campaign_key, custom_variables, variation_targeting_variables)

    # Check if variation_name has been assigned
    unless valid_value?(variation)
      # log invalid variation key
      @logger.log(
        LogLevelEnum::INFO,
        format(
          LogMessageEnum::InfoMessages::INVALID_VARIATION_KEY,
          file: FILE,
          user_id: user_id,
          campaign_key: campaign_key
        )
      )
      return
    end

    variation['name']
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      format(
        LogMessageEnum::ErrorMessages::API_NOT_WORKING,
        file: FILE,
        api_name: ApiMethods::GET_VARIATION_NAME,
        exception: e
      )
    )
    nil
  end

  # This API method: Marks the conversion of the campaign
  # for a particular goal
  # 1. validates the arguments being passed
  # 2. Checks if user is eligible to get bucketed into the campaign,
  # 3. Gets the assigned deterministic variation to the
  #     user(based on user_d), if user becomes part of campaign
  # 4. Sends an impression call to VWO server to track goal data
  #
  # @param[String]                      :campaign_key     Unique campaign key
  # @param[String]                      :user_id          ID assigned to a user
  # @param[String]                      :goal_identifier  Unique campaign's goal identifier
  # @param[Array|Hash]                  :args             Contains revenue value and custom variables
  # @param[Numeric|String]              :revenue_value    It is the revenue generated on triggering the goal
  #
  def track(campaign_key, user_id, goal_identifier, *args)
    if args[0].is_a?(Hash)
      revenue_value = args[0]['revenue_value'] || args[0][:revenue_value]
      custom_variables = args[0]['custom_variables'] || args[0][:custom_variables]
      variation_targeting_variables = args[0]['variation_targeting_variables'] || args[0][:variation_targeting_variables]
    elsif args.is_a?(Array)
      revenue_value = args[0]
      custom_variables = nil
    end

    # Check for valid args
    unless valid_string?(campaign_key) && valid_string?(user_id) && (custom_variables.nil? || valid_hash?(custom_variables)) &&
           (variation_targeting_variables.nil? || valid_hash?(variation_targeting_variables))
      # log invalid params
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::TRACK_API_INVALID_PARAMS,
          file: FILE,
          api_name: ApiMethods.TRACK
        )
      )
      return false
    end

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::API_CONFIG_CORRUPTED,
          file: FILE,
          api_name: ApiMethods::TRACK
        )
      )
      return false
    end

    # Get the campaign settings
    campaign = get_campaign(@settings_file, campaign_key)

    # Validate campaign
    if campaign.nil? || (campaign['status'] != STATUS_RUNNING)
      # log error
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::CAMPAIGN_NOT_RUNNING,
          file: FILE,
          campaign_key: campaign_key,
          api_name: ApiMethods::TRACK
        )
      )
      return false
    end

    campaign_type = campaign['type']

    if campaign_type == CampaignTypes::FEATURE_ROLLOUT
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::INVALID_API,
          file: FILE,
          api_name: ApiMethods::TRACK,
          user_id: user_id,
          campaign_key: campaign_key,
          campaign_type: campaign_type
        )
      )
      return false
    end

    variation = @variation_decider.get_variation(user_id, campaign, ApiMethods::TRACK, campaign_key, custom_variables, variation_targeting_variables)

    if variation
      goal = get_campaign_goal(campaign, goal_identifier)
      if goal.nil?
        @logger.log(
          LogLevelEnum::ERROR,
          format(
            LogMessageEnum::ErrorMessages::TRACK_API_GOAL_NOT_FOUND,
            file: FILE,
            goal_identifier: goal_identifier,
            user_id: user_id,
            campaign_key: campaign_key,
            api_name: ApiMethods::TRACK
          )
        )
        return false
      elsif goal['type'] == GoalTypes::REVENUE && !valid_value?(revenue_value)
        @logger.log(
          LogLevelEnum::ERROR,
          format(
            LogMessageEnum::ErrorMessages::TRACK_API_REVENUE_NOT_PASSED_FOR_REVENUE_GOAL,
            file: FILE,
            user_id: user_id,
            goal_identifier: goal_identifier,
            campaign_key: campaign_key,
            api_name: ApiMethods::TRACK
          )
        )
        return false
      elsif goal['type'] == GoalTypes::CUSTOM
        revenue_value = nil
      end
      impression = create_impression(
        @settings_file,
        campaign['id'],
        variation['id'],
        user_id,
        goal['id'],
        revenue_value
      )
      @event_dispatcher.dispatch(impression)

      @logger.log(
        LogLevelEnum::INFO,
        format(
          LogMessageEnum::InfoMessages::MAIN_KEYS_FOR_IMPRESSION,
          file: FILE,
          campaign_id: impression[:experiment_id],
          user_id: impression[:uId],
          account_id: impression[:account_id],
          variation_id: impression[:combination]
        )
      )
      return true
    end
    false
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      format(
        LogMessageEnum::ErrorMessages::API_NOT_WORKING,
        file: FILE,
        api_name: ApiMethods::TRACK,
        exception: e
      )
    )
    false
  end

  # This API method: Identifies whether the user becomes a part of feature rollout/test or not.
  # 1. Validates the arguments being passed
  # 2. Checks if user is eligible to get bucketed into the feature test/rollout,
  # 3. Assigns the deterministic variation to the user(based on userId),
  #    If user becomes part of feature test/rollout
  #    If UserStorage is used, it will look into it for the variation and if found, no further processing is done
  #
  # @param[String]                :campaign_key                       Unique campaign key
  # @param[String]                :user_id                            ID assigned to a user
  # @param[Hash]                  :custom_variables                   Pass it through options as custom_variables={}
  #
  # @return[Boolean]  true if user becomes part of feature test/rollout, otherwise false.

  def feature_enabled?(campaign_key, user_id, options = {})
    # Retrieve custom variables
    custom_variables = options['custom_variables'] || options[:custom_variables]
    variation_targeting_variables = options['variation_targeting_variables'] || options[:variation_targeting_variables]

    # Validate input parameters
    unless valid_string?(campaign_key) && valid_string?(user_id) && (custom_variables.nil? || valid_hash?(custom_variables)) &&
           (variation_targeting_variables.nil? || valid_hash?(variation_targeting_variables))
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::IS_FEATURE_ENABLED_API_INVALID_PARAMS,
          api_name: ApiMethods::IS_FEATURE_ENABLED,
          file: FILE
        )
      )
      return false
    end
    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::API_CONFIG_CORRUPTED,
          file: FILE,
          api_name: ApiMethods::IS_FEATURE_ENABLED
        )
      )
      return false
    end

    # Get the campaign settings
    campaign = get_campaign(@settings_file, campaign_key)

    # Validate campaign
    unless campaign && campaign['status'] == STATUS_RUNNING
      # log error
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::CAMPAIGN_NOT_RUNNING,
          file: FILE,
          campaign_key: campaign_key,
          api_name: ApiMethods::IS_FEATURE_ENABLED
        )
      )
      return false
    end

    # Validate campaign_type
    campaign_type = campaign['type']

    if campaign_type == CampaignTypes::VISUAL_AB
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::INVALID_API,
          file: FILE,
          api_name: ApiMethods::IS_FEATURE_ENABLED,
          user_id: user_id,
          campaign_key: campaign_key,
          campaign_type: campaign_type
        )
      )
      return false
    end

    # Get variation
    variation = @variation_decider.get_variation(user_id, campaign, ApiMethods::IS_FEATURE_ENABLED, campaign_key, custom_variables, variation_targeting_variables)

    # If no variation, did not become part of feature_test/rollout
    return false unless variation

    # if campaign type is feature_test Send track call to server
    if campaign_type == CampaignTypes::FEATURE_TEST
      impression = create_impression(
        @settings_file,
        campaign['id'],
        variation['id'],
        user_id
      )

      @event_dispatcher.dispatch(impression)
      @logger.log(
        LogLevelEnum::INFO,
        format(
          LogMessageEnum::InfoMessages::MAIN_KEYS_FOR_IMPRESSION,
          file: FILE,
          campaign_id: impression[:experiment_id],
          user_id: impression[:uId],
          account_id: impression[:account_id],
          variation_id: impression[:combination]
        )
      )
      result = variation['isFeatureEnabled']
      if result
        @logger.log(
          LogLevelEnum::INFO,
          format(
            LogMessageEnum::InfoMessages::FEATURE_ENABLED_FOR_USER,
            file: FILE,
            user_id: user_id,
            feature_key: campaign_key,
            api_name: ApiMethods::IS_FEATURE_ENABLED
          )
        )
      else
        @logger.log(
          LogLevelEnum::INFO,
          format(
            LogMessageEnum::InfoMessages::FEATURE_NOT_ENABLED_FOR_USER,
            file: FILE,
            user_id: user_id,
            feature_key: campaign_key,
            api_name: ApiMethods::IS_FEATURE_ENABLED
          )
        )
      end
      return result
    end
    true
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      format(
        LogMessageEnum::ErrorMessages::API_NOT_WORKING,
        file: FILE,
        api_name: ApiMethods::IS_FEATURE_ENABLED,
        exception: e
      )
    )
    false
  end

  # Returns the feature variable corresponding to the variable_key
  # passed. It typecasts the value to the corresponding value type
  # found in settings_file
  #
  # 1. Validates the arguments being passed
  # 2. Checks if user is eligible to get bucketed into the feature test/rollout,
  # 3. Assigns the deterministic variation to the user(based on userId),
  #     If user becomes part of campaign
  #     If UserStorage is used, it will look into it for the variation and if found, no further processing is done
  # 4. Retrieves the corresponding variable from variation assigned.
  #
  # @param[String]              :campaign_key           Unique campaign key
  # @param[String]              :variable_key           Variable key
  # @param[String]              :user_id                ID assigned to a user
  # @param[Hash]                :custom_variables       Pass it through options as custom_variables={}
  #
  # @return[Boolean, String, Integer, Float, nil)      If variation is assigned then variable corresponding to variation assigned else nil
  #

  def get_feature_variable_value(campaign_key, variable_key, user_id, options = {})
    # Retrieve custom variables
    custom_variables = options['custom_variables'] || options[:custom_variables]
    variation_targeting_variables = options['variation_targeting_variables'] || options[:variation_targeting_variables]

    unless valid_string?(campaign_key) && valid_string?(variable_key) && valid_string?(user_id) &&
           (custom_variables.nil? || valid_hash?(custom_variables)) && (variation_targeting_variables.nil? || valid_hash?(variation_targeting_variables))
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::GET_FEATURE_VARIABLE_VALUE_API_INVALID_PARAMS,
          file: FILE,
          api_name: ApiMethods::GET_FEATURE_VARIABLE_VALUE
        )
      )
      return
    end

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::API_CONFIG_CORRUPTED,
          file: FILE,
          api_name: ApiMethods.GET_FEATURE_VARIABLE_VALUE
        )
      )
      return
    end

    # Get the campaign settings
    campaign = get_campaign(@settings_file, campaign_key)

    # Validate campaign
    unless campaign && campaign['status'] == STATUS_RUNNING
      # log error
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::CAMPAIGN_NOT_RUNNING,
          file: FILE,
          campaign_key: campaign_key,
          api_name: ApiMethods::GET_FEATURE_VARIABLE_VALUE
        )
      )
      return
    end

    campaign_type = campaign['type']

    if campaign_type == CampaignTypes::VISUAL_AB
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::INVALID_API,
          file: FILE,
          api_name: ApiMethods::GET_FEATURE_VARIABLE_VALUE,
          campaign_key: campaign_key,
          campaign_type: campaign_type,
          user_id: user_id
        )
      )
      return
    end

    variation = @variation_decider.get_variation(user_id, campaign, ApiMethods::GET_FEATURE_VARIABLE_VALUE, campaign_key, custom_variables, variation_targeting_variables)

    # Check if variation has been assigned to user
    return unless variation

    if campaign_type == CampaignTypes::FEATURE_ROLLOUT
      variables = campaign['variables']
    elsif campaign_type == CampaignTypes::FEATURE_TEST
      if !variation['isFeatureEnabled']
        @logger.log(
          LogLevelEnum::INFO,
          format(
            LogMessageEnum::InfoMessages::FEATURE_NOT_ENABLED_FOR_USER,
            file: FILE,
            feature_key: campaign_key,
            user_id: user_id,
            api_name: ApiMethods::GET_FEATURE_VARIABLE_VALUE
          )
        )
        variation = get_control_variation(campaign)
      else
        @logger.log(
          LogLevelEnum::INFO,
          format(
            LogMessageEnum::InfoMessages::FEATURE_ENABLED_FOR_USER,
            file: FILE,
            feature_key: campaign_key,
            user_id: user_id,
            api_name: ApiMethods::GET_FEATURE_VARIABLE_VALUE
          )
        )
      end
      variables = variation['variables']
    end
    variable = get_variable(variables, variable_key)

    unless variable
      # Log variable not found
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::VARIABLE_NOT_FOUND,
          file: FILE,
          variable_key: variable_key,
          campaign_key: campaign_key,
          campaign_type: campaign_type,
          user_id: user_id,
          api_name: ApiMethods::GET_FEATURE_VARIABLE_VALUE
        )
      )
      return
    end

    @logger.log(
      LogLevelEnum::INFO,
      format(
        LogMessageEnum::InfoMessages::VARIABLE_FOUND,
        file: FILE,
        variable_key: variable_key,
        variable_value: variable['value'],
        campaign_key: campaign_key,
        campaign_type: campaign_type,
        user_id: user_id,
        api_name: ApiMethods::GET_FEATURE_VARIABLE_VALUE
      )
    )
    get_type_casted_feature_value(variable['value'], variable['type'])
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      format(
        LogMessageEnum::ErrorMessages::API_NOT_WORKING,
        file: FILE,
        api_name: ApiMethods::GET_FEATURE_VARIABLE_VALUE,
        exception: e
      )
    )
    nil
  end

  # This API method: Makes a call to our server to store the tag_values
  # 1. Validates the arguments being passed
  # 2. Send a call to our server
  # @param[String]          :tag_key              key name of the tag
  # @param[String]          :tag_value            Value of the tag
  # @param[String]          :user_id              ID of the user for which value should be stored
  # @return                                       true if call is made successfully, else false

  def push(tag_key, tag_value, user_id)
    unless valid_string?(tag_key) && valid_string?(tag_value) && valid_string?(user_id)
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::PUSH_API_INVALID_PARAMS,
          file: FILE,
          api_name: ApiMethods::PUSH
        )
      )
      return false
    end

    if tag_key.length > PushApi::TAG_KEY_LENGTH
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::TAG_KEY_LENGTH_EXCEEDED,
          file: FILE,
          user_id: user_id,
          tag_key: tag_key,
          api_name: ApiMethods::PUSH
        )
      )
      return false
    end

    if tag_value.length > PushApi::TAG_VALUE_LENGTH
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::TAG_VALUE_LENGTH_EXCEEDED,
          file: FILE,
          user_id: user_id,
          tag_value: tag_value,
          api_name: ApiMethods::PUSH
        )
      )
      return false
    end

    impression = get_url_params(@settings_file, tag_key, tag_value, user_id)

    @event_dispatcher.dispatch(impression)

    @logger.log(
      LogLevelEnum::INFO,
      format(
        LogMessageEnum::InfoMessages::MAIN_KEYS_FOR_PUSH_API,
        file: FILE,
        u: impression['u'],
        user_id: impression['uId'],
        account_id: impression['account_id'],
        tags: impression['tags']
      )
    )
    true
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      format(
        LogMessageEnum::ErrorMessages::API_NOT_WORKING,
        file: FILE,
        api_name: ApiMethods::PUSH,
        exception: e
      )
    )
    false
  end
end

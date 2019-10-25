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

# frozen_string_literal: true

require_relative 'vwo/services/settings_file_manager'
require_relative 'vwo/services/event_dispatcher'
require_relative 'vwo/services/settings_file_processor'
require_relative 'vwo/logger'
require_relative 'vwo/enums'
require_relative 'vwo/utils/campaign'
require_relative 'vwo/utils/impression'
require_relative 'vwo/constants'
require_relative 'vwo/core/variation_decider'


# VWO main file
class VWO
  attr_accessor :is_instance_valid

  include Enums
  include Utils::Validations
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
    settings_file = nil
  )
    @account_id = account_id
    @sdk_key = sdk_key
    @user_storage = user_storage
    @is_development_mode = is_development_mode
    @logger = VWO::Logger.get_instance(logger)

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
      format(LogMessageEnum::DebugMessages::VALID_CONFIGURATION, file: FILE)
    )

    # Process the settings file
    @config.process_settings_file
    @settings_file = @config.get_settings_file

    # Assign VariationDecider to VWO
    @variation_decider = VWO::Core::VariationDecider.new(@settings_file, user_storage)

    if is_development_mode
      @logger.log(
        LogLevelEnum::DEBUG,
        format(LogMessageEnum::DebugMessages::SET_DEVELOPMENT_MODE, file: FILE)
      )
    end
    # Assign event dispatcher
    @event_dispatcher = VWO::Services::EventDispatcher.new(is_development_mode)

    # Successfully initialized VWO SDK
    @logger.log(
      LogLevelEnum::DEBUG,
      format(LogMessageEnum::DebugMessages::SDK_INITIALIZED, file: FILE)
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
  # @return[String|None]                          If variation is assigned then variation-name
  #                                               otherwise null in case of user not becoming part

  def activate(campaign_key, user_id)
    # Validate input parameters
    unless valid_string?(campaign_key) && valid_string?(user_id)
      @logger.log(
        LogLevelEnum::ERROR,
        format(LogMessageEnum::ErrorMessages::ACTIVATE_API_MISSING_PARAMS, file: FILE)
      )
      return
    end

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        format(LogMessageEnum::ErrorMessages::ACTIVATE_API_CONFIG_CORRUPTED, file: FILE)
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
        format(LogMessageEnum::ErrorMessages::CAMPAIGN_NOT_RUNNING, file: FILE, campaign_key: campaign_key, api: 'activate')
      )
      return
    end

    # Once the matching RUNNING campaign is found, assign the
    # deterministic variation to the user_id provided
    variation_id, variation_name = @variation_decider.get_variation(
      user_id,
      campaign
    )

    # Check if variation_name has been assigned
    unless valid_value?(variation_name)
      @logger.log(
        LogLevelEnum::INFO,
        format(LogMessageEnum::InfoMessages::INVALID_VARIATION_KEY, file: FILE, user_id: user_id, campaign_key: campaign_key)
      )
      return
    end

    # Variation found, dispatch it to server
    impression = create_impression(
      @settings_file,
      campaign['id'],
      variation_id,
      user_id
    )
    @event_dispatcher.dispatch(impression)
    variation_name
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
  #
  # @@return[String|Nil]                                  If variation is assigned then variation-name
  #                                                       Otherwise null in case of user not becoming part
  #
  def get_variation_name(campaign_key, user_id)
    # Check for valid arguments
    unless valid_string?(campaign_key) && valid_string?(user_id)
      # log invalid params
      @logger.log(
        LogLevelEnum::ERROR,
        format(LogMessageEnum::ErrorMessages::GET_VARIATION_NAME_API_MISSING_PARAMS, file: FILE)
      )
      return
    end

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        format(LogMessageEnum::ErrorMessages::ACTIVATE_API_CONFIG_CORRUPTED, file: FILE)
      )
      return
    end

    # Get the campaign settings
    campaign = get_campaign(@settings_file, campaign_key)

    # Validate campaign
    if campaign.nil? || campaign['status'] != STATUS_RUNNING
      @logger.log(
        LogLevelEnum::ERROR,
        format(LogMessageEnum::ErrorMessages::CAMPAIGN_NOT_RUNNING, file: FILE, campaign_key: campaign_key, api: 'get_variation')
      )
      return
    end

    _variation_id, variation_name = @variation_decider.get_variation(
      user_id,
      campaign
    )

    # Check if variation_name has been assigned
    unless valid_value?(variation_name)
      # log invalid variation key
      @logger.log(
        LogLevelEnum::INFO,
        format(LogMessageEnum::InfoMessages::INVALID_VARIATION_KEY, file: FILE, user_id: user_id, campaign_key: campaign_key)
      )
      return
    end

    variation_name
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
  # @param[String]                      :goal_identifier   Unique campaign's goal identifier
  # @param[Numeric|String]              :revenue_value    Revenue value for revenue-type goal
  #
  def track(campaign_key, user_id, goal_identifier, *args)
    if args[0].is_a?(Hash)
      revenue_value = args[0]['revenue_value']
    elsif args.is_a?(Array)
      revenue_value = args[0]
    end

    # Check for valid args
    unless valid_string?(campaign_key) && valid_string?(user_id) && valid_string?(goal_identifier)
      # log invalid params
      @logger.log(
        LogLevelEnum::ERROR,
        format(LogMessageEnum::ErrorMessages::TRACK_API_MISSING_PARAMS, file: FILE)
      )
      return false
    end

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        format(LogMessageEnum::ErrorMessages::ACTIVATE_API_CONFIG_CORRUPTED, file: FILE)
      )
      return false
    end

    # Get the campaign settings
    campaign = get_campaign(@settings_file, campaign_key)

    # Validate campaign
    if campaign.nil? || campaign['status'] != STATUS_RUNNING
      # log error
      @logger.log(
        LogLevelEnum::ERROR,
        format(LogMessageEnum::ErrorMessages::CAMPAIGN_NOT_RUNNING, file: FILE, campaign_key: campaign_key, api: 'track')
      )
      return false
    end

    campaign_id = campaign['id']
    variation_id, variation_name = @variation_decider.get_variation_allotted(user_id, campaign)

    if variation_name
      goal = get_campaign_goal(@settings_file, campaign['key'], goal_identifier)

      if goal.nil?
        @logger.log(
          LogLevelEnum::ERROR,
          format(
            LogMessageEnum::ErrorMessages::TRACK_API_GOAL_NOT_FOUND,
            file: FILE, goal_identifier: goal_identifier,
            user_id: user_id,
            campaign_key: campaign_key
          )
        )
        return false
      elsif goal['type'] == GOALTYPES::REVENUE && !valid_value?(revenue_value)
        @logger.log(
          LogLevelEnum::ERROR,
          format(
            LogMessageEnum::ErrorMessages::TRACK_API_REVENUE_NOT_PASSED_FOR_REVENUE_GOAL,
            file: FILE,
            user_id: user_id,
            goal_identifier: goal_identifier,
            campaign_key: campaign_key
          )
        )
        return false
      end

      revenue_value = nil if goal['type'] == GOALTYPES::CUSTOM

      impression = create_impression(
        @settings_file,
        campaign_id,
        variation_id,
        user_id,
        goal['id'],
        revenue_value
      )
      @event_dispatcher.dispatch(impression)
      return true
    end
    false
  end
end

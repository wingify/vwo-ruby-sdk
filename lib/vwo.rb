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
require_relative 'vwo/utils/utility'
require_relative 'vwo/constants'
require_relative 'vwo/core/variation_decider'
require_relative 'vwo/services/batch_events_dispatcher'
require_relative 'vwo/services/batch_events_queue'
require_relative 'vwo/services/usage_stats'

# VWO main file
class VWO
  attr_accessor :is_instance_valid, :logger, :settings_file_manager, :variation_decider
  attr_reader :usage_stats
  include Enums
  include Utils::Validations
  include Utils::Feature
  include Utils::CustomDimensions
  include Utils::Campaign
  include Utils::Impression
  include Utils::Utility
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
    options = convert_to_symbol_hash(options)
    @account_id = account_id
    @sdk_key = sdk_key
    @user_storage = user_storage
    @is_development_mode = is_development_mode
    @logger = VWO::Logger.get_instance(logger)
    @logger.instance.level = options[:log_level] if (0..5).include?(options[:log_level])
    usage_stats = {}

    usage_stats[:cl] = 1 if logger
    usage_stats[:ll] = 1 if options[:log_level]
    usage_stats[:ss] = 1 if @user_storage
    usage_stats[:ig] = 1 if options.key?(:integrations)
    usage_stats[:eb] = 1 if options.key?(:batch_events)

    @settings_file_manager = VWO::Services::SettingsFileManager.new(@account_id, @sdk_key)
    unless valid_settings_file?(get_settings(settings_file))
      @logger.log(
        LogLevelEnum::ERROR,
        format(LogMessageEnum::ErrorMessages::SETTINGS_FILE_CORRUPTED, file: FILE)
      )
      @is_instance_valid = false
      return
    end

    if options.key?(:goal_type_to_track)
      if GOAL_TYPES.key? options[:goal_type_to_track]
        @goal_type_to_track = options[:goal_type_to_track]
        usage_stats[:gt] = 1
      else
        @logger.log(
          LogLevelEnum::ERROR,
          format(
            LogMessageEnum::ErrorMessages::INVALID_GOAL_TYPE,
            file: FILE
          )
        )
        @is_instance_valid = false
        return
      end
    else
      @goal_type_to_track = 'ALL'
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

    @usage_stats = VWO::Services::UsageStats.new(usage_stats, @is_development_mode)

    if options.key?(:batch_events)
      if options[:batch_events].is_a?(Hash)
        unless is_valid_batch_event_settings(options[:batch_events])
          @is_instance_valid = false
          return
        end
        @batch_event_dispatcher = VWO::Services::BatchEventsDispatcher.new
        def dispatcher (events, callback)
          @batch_event_dispatcher.dispatch(
            {
              ev: events
            },
            callback,
            {
              a: @account_id,
              sd: SDK_NAME,
              sv: SDK_VERSION,
              env: @sdk_key
            }.merge(@usage_stats.usage_stats)
          )
        end
        @batch_events_queue = VWO::Services::BatchEventsQueue.new(
          options[:batch_events].merge(
            {
              account_id: @account_id,
              dispatcher: method(:dispatcher)
            }
          )
        )
        @batch_events_queue.flush(manual: true)
        @batch_events = options[:batch_events]
      else
        @logger.log(
          LogLevelEnum::ERROR,
          format(
            LogMessageEnum::ErrorMessages::EVENT_BATCHING_NOT_OBJECT,
            file: FILE
          )
        )
        @is_instance_valid = false
        return
      end
    end

    # Assign VariationDecider to VWO
    @variation_decider = VWO::Core::VariationDecider.new(@settings_file, user_storage, options)

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
    @settings_file ||=
      settings_file || @settings_file_manager.get_settings_file
    @settings_file
  end

  # This API method: fetch the latest settings file and update it

  # VWO get_settings method to get settings for a particular account_id
  def get_and_update_settings_file

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::API_CONFIG_CORRUPTED,
          file: FILE,
          api_name: ApiMethods.GET_AND_UPDATE_SETTINGS_FILE
        )
      )
      return
    end

    latest_settings = @settings_file_manager.get_settings_file(true)
    latest_settings = JSON.parse(latest_settings)
    if latest_settings == @settings_file
      @logger.log(
        LogLevelEnum::INFO,
        format(
          LogMessageEnum::InfoMessages::SETTINGS_NOT_UPDATED,
          api_name: ApiMethods::GET_AND_UPDATE_SETTINGS_FILE,
          file: FILE
        )
      )
    end

    @config.update_settings_file(latest_settings)
    @settings_file = @config.get_settings_file
    @settings_file
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      format(
        LogMessageEnum::ErrorMessages::API_NOT_WORKING,
        file: FILE,
        api_name: ApiMethods::GET_AND_UPDATE_SETTINGS_FILE,
        exception: e
      )
    )
    nil
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
  # @param[Hash]              :options            Options for custom variables required for segmentation
  # @return[String|None]                          If variation is assigned then variation-name
  #                                               otherwise null in case of user not becoming part

  def activate(campaign_key, user_id, options = {})
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

    options = convert_to_symbol_hash(options)
    # Retrieve custom variables
    custom_variables = options[:custom_variables]
    variation_targeting_variables = options[:variation_targeting_variables]

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

    if is_eligible_to_send_impression()
      if defined?(@batch_events)
        impression = create_bulk_event_impression(
          @settings_file,
          campaign['id'],
          variation['id'],
          user_id
        )
        @batch_events_queue.enqueue(impression)
      elsif is_event_arch_enabled
        properties = get_events_base_properties(@settings_file, EventEnum::VWO_VARIATION_SHOWN, @usage_stats.usage_stats)
        payload = get_track_user_payload_data(@settings_file, user_id, EventEnum::VWO_VARIATION_SHOWN, campaign['id'], variation['id'])
        @event_dispatcher.dispatch_event_arch_post(properties, payload)
      else
        # Variation found, dispatch it to server
        impression = create_impression(
          @settings_file,
          campaign['id'],
          variation['id'],
          user_id,
          @sdk_key,
          nil, # goal_id
          nil, # revenue
          usage_stats: @usage_stats.usage_stats
        )
        if @event_dispatcher.dispatch(impression)
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::IMPRESSION_SUCCESS,
              file: FILE,
              account_id: @account_id,
              campaign_id: campaign['id'],
              variation_id: variation['id'],
              end_point: EVENTS::TRACK_USER
            )
          )
        end
      end
    else
      @logger.log(
        LogLevelEnum::INFO,
        format(
          LogMessageEnum::InfoMessages::USER_ALREADY_TRACKED,
          file: FILE,
          user_id: user_id,
          campaign_key: campaign_key,
          api_name: ApiMethods::ACTIVATE
        )
      )
    end
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
    e
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
    options = convert_to_symbol_hash(options)
    # Retrieve custom variables
    custom_variables = options[:custom_variables]
    variation_targeting_variables = options[:variation_targeting_variables]

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
  # @param[Hash]                        :options             Contains revenue value and custom variables
  # @param[Numeric|String]              :revenue_value    It is the revenue generated on triggering the goal
  #

  def track(campaign_key, user_id, goal_identifier, options = {})
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

    options = convert_to_symbol_hash(options)
    revenue_value = options[:revenue_value]
    custom_variables = options[:custom_variables]
    variation_targeting_variables = options[:variation_targeting_variables]
    goal_type_to_track = get_goal_type_to_track(options)

    # Check for valid args
    unless (valid_string?(campaign_key) || campaign_key.is_a?(Array) || campaign_key.nil?) && valid_string?(user_id) && valid_string?(goal_identifier) && (custom_variables.nil? || valid_hash?(custom_variables)) &&
      (variation_targeting_variables.nil? || valid_hash?(variation_targeting_variables)) && (GOAL_TYPES.key? (goal_type_to_track))
      # log invalid params
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::TRACK_API_INVALID_PARAMS,
          file: FILE,
          api_name: ApiMethods::TRACK
        )
      )
      return false
    end

    # Get campaigns settings
    campaigns = get_campaigns(@settings_file, campaign_key, goal_identifier, goal_type_to_track)

    # Validate campaign
    if campaigns.nil?
      return nil
    end

    metric_map = {}
    revenue_props = []
    result = {}
    campaigns.each do |campaign|
      begin
        campaign_type = campaign['type']

        if campaign_type == CampaignTypes::FEATURE_ROLLOUT
          @logger.log(
            LogLevelEnum::ERROR,
            format(
              LogMessageEnum::ErrorMessages::INVALID_API,
              file: FILE,
              api_name: ApiMethods::TRACK,
              user_id: user_id,
              campaign_key: campaign['key'],
              campaign_type: campaign_type
            )
          )
          result[campaign['key']] = false
          next
        end

        variation = @variation_decider.get_variation(user_id, campaign, ApiMethods::TRACK, campaign['key'], custom_variables, variation_targeting_variables, goal_identifier)

        if variation
          goal = get_campaign_goal(campaign, goal_identifier)
          if goal.nil? || !goal["id"]
            @logger.log(
              LogLevelEnum::ERROR,
              format(
                LogMessageEnum::ErrorMessages::TRACK_API_GOAL_NOT_FOUND,
                file: FILE,
                goal_identifier: goal_identifier,
                user_id: user_id,
                campaign_key: campaign['key'],
                api_name: ApiMethods::TRACK
              )
            )
            result[campaign['key']] = false
            next
          elsif goal['type'] == GoalTypes::REVENUE && !valid_value?(revenue_value)
            @logger.log(
              LogLevelEnum::ERROR,
              format(
                LogMessageEnum::ErrorMessages::TRACK_API_REVENUE_NOT_PASSED_FOR_REVENUE_GOAL,
                file: FILE,
                user_id: user_id,
                goal_identifier: goal_identifier,
                campaign_key: campaign['key'],
                api_name: ApiMethods::TRACK
              )
            )
            result[campaign['key']] = false
            next
          elsif goal['type'] == GoalTypes::CUSTOM
            revenue_value = nil
          end

          if variation['goal_identifier']
            identifiers = variation['goal_identifier'].split(VWO_DELIMITER)
          else
            variation['goal_identifier'] = ''
            identifiers = []
          end

          if !identifiers.include? goal_identifier
            updated_goal_identifier = variation['goal_identifier']
            updated_goal_identifier += VWO_DELIMITER + goal_identifier
            @variation_decider.save_user_storage(user_id, campaign['key'], campaign['name'], variation['name'], updated_goal_identifier) if variation['name']
            # set variation at user storage
          else
            @logger.log(
              LogLevelEnum::INFO,
              format(
                LogMessageEnum::InfoMessages::GOAL_ALREADY_TRACKED,
                file: FILE,
                user_id: user_id,
                campaign_key: campaign['key'],
                goal_identifier: goal_identifier,
                api_name: ApiMethods::TRACK
              )
            )
            result[campaign['key']] = false
            next
          end

          if defined?(@batch_events)
            impression = create_bulk_event_impression(
              @settings_file,
              campaign['id'],
              variation['id'],
              user_id,
              goal['id'],
              revenue_value
            )
            @batch_events_queue.enqueue(impression)
          elsif  is_event_arch_enabled
            metric_map[campaign['id']] = goal['id']
            if goal['type'] == GoalTypes::REVENUE && !(revenue_props.include? goal['revenueProp'])
              revenue_props << goal['revenueProp']
            end
          else
            impression = create_impression(
              @settings_file,
              campaign['id'],
              variation['id'],
              user_id,
              @sdk_key,
              goal['id'],
              revenue_value
            )
            if @event_dispatcher.dispatch(impression)
              @logger.log(
                LogLevelEnum::INFO,
                format(
                  LogMessageEnum::InfoMessages::IMPRESSION_SUCCESS,
                  file: FILE,
                  account_id: @account_id,
                  campaign_id: campaign['id'],
                  variation_id: variation['id'],
                  end_point: EVENTS::TRACK_GOAL
                )
              )
              @logger.log(
                LogLevelEnum::INFO,
                format(
                  LogMessageEnum::InfoMessages::MAIN_KEYS_FOR_IMPRESSION,
                  file: FILE,
                  campaign_id: impression[:experiment_id],
                  account_id: impression[:account_id],
                  variation_id: impression[:combination]
                )
              )
            end
          end
          result[campaign['key']] = true
          next
        end
        result[campaign['key']] = false
      rescue StandardError => e
        @logger.log(
          LogLevelEnum::ERROR,
          format(
            e.message,
            file: FILE,
            exception: e
          )
        )
      end
    end

    if is_event_arch_enabled
      properties = get_events_base_properties(@settings_file, goal_identifier)
      payload = get_track_goal_payload_data(@settings_file, user_id, goal_identifier, revenue_value, metric_map, revenue_props)
      @event_dispatcher.dispatch_event_arch_post(properties, payload)
    end

    if result.length() == 0
      return nil
    end

    result
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

    options = convert_to_symbol_hash(options)
    # Retrieve custom variables
    custom_variables = options[:custom_variables]
    variation_targeting_variables = options[:variation_targeting_variables]
    @logger.log(
      LogLevelEnum::INFO,
      format(
        LogMessageEnum::InfoMessages::API_CALLED,
        file: FILE,
        api_name: ApiMethods::IS_FEATURE_ENABLED,
        user_id: user_id
      )
    )
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

    if is_eligible_to_send_impression()
      if defined?(@batch_events)
        impression = create_bulk_event_impression(
          @settings_file,
          campaign['id'],
          variation['id'],
          user_id
        )
        @batch_events_queue.enqueue(impression)
      elsif is_event_arch_enabled
        properties = get_events_base_properties(@settings_file, EventEnum::VWO_VARIATION_SHOWN, @usage_stats.usage_stats)
        payload = get_track_user_payload_data(@settings_file, user_id, EventEnum::VWO_VARIATION_SHOWN, campaign['id'], variation['id'])
        @event_dispatcher.dispatch_event_arch_post(properties, payload)
      else
        impression = create_impression(
          @settings_file,
          campaign['id'],
          variation['id'],
          user_id,
          @sdk_key,
          nil,
          nil,
          usage_stats: @usage_stats.usage_stats
        )

        @event_dispatcher.dispatch(impression)
        @logger.log(
          LogLevelEnum::INFO,
          format(
            LogMessageEnum::InfoMessages::MAIN_KEYS_FOR_IMPRESSION,
            file: FILE,
            campaign_id: impression[:experiment_id],
            account_id: impression[:account_id],
            variation_id: impression[:combination]
          )
        )
      end

    else
      @logger.log(
        LogLevelEnum::INFO,
        format(
          LogMessageEnum::InfoMessages::USER_ALREADY_TRACKED,
          file: FILE,
          user_id: user_id,
          campaign_key: campaign_key,
          api_name: ApiMethods::IS_FEATURE_ENABLED
        )
      )
    end
    if campaign_type == CampaignTypes::FEATURE_ROLLOUT
      result = true
    else
      result = variation['isFeatureEnabled']
    end

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

    result
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

    options = convert_to_symbol_hash(options)
    # Retrieve custom variables
    custom_variables = options[:custom_variables]
    variation_targeting_variables = options[:variation_targeting_variables]

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
  # @param[String|Hash]     :tag_key              key name of the tag OR tagKey/tagValue pair(custom dimension map)
  # @param[String]          :tag_value            Value of the tag OR userId if TagKey is hash
  # @param[String]          :user_id              ID of the user for which value should be stored
  # @return                                       true if call is made successfully, else false

  def push(tag_key, tag_value, user_id = nil)
    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::API_CONFIG_CORRUPTED,
          file: FILE,
          api_name: ApiMethods.PUSH
        )
      )
      return
    end

    # Argument reshuffling.
    custom_dimension_map = {}
    if user_id.nil? || tag_key.is_a?(Hash)
      custom_dimension_map = convert_to_symbol_hash(tag_key)
      user_id = tag_value
    else
      custom_dimension_map[tag_key.to_sym] = tag_value
    end

    unless (valid_string?(tag_key) || valid_hash?(tag_key)) && valid_string?(tag_value) && valid_string?(user_id)
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

    custom_dimension_map.each do |tag_key, tag_value|
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
    end

    if defined?(@batch_events)
      custom_dimension_map.each do |tag_key, tag_value|
        impression = get_batch_event_url_params(@settings_file, tag_key, tag_value, user_id)
        @batch_events_queue.enqueue(impression)
      end
    elsif is_event_arch_enabled
      properties = get_events_base_properties(@settings_file, EventEnum::VWO_SYNC_VISITOR_PROP)
      payload = get_push_payload_data(@settings_file, user_id, EventEnum::VWO_SYNC_VISITOR_PROP, custom_dimension_map)
      @event_dispatcher.dispatch_event_arch_post(properties, payload)
    else
      custom_dimension_map.each do |tag_key, tag_value|
        impression = get_url_params(@settings_file, tag_key, tag_value, user_id, @sdk_key)
        @event_dispatcher.dispatch(impression)

        @logger.log(
          LogLevelEnum::INFO,
          format(
            LogMessageEnum::InfoMessages::MAIN_KEYS_FOR_PUSH_API,
            file: FILE,
            u: impression['u'],
            account_id: impression['account_id'],
            tags: impression['tags']
          )
        )
      end
    end
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

  def is_eligible_to_send_impression()
    !@user_storage || !@variation_decider.has_stored_variation
  end

  def flush_events
    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::API_CONFIG_CORRUPTED,
          file: FILE,
          api_name: ApiMethods::FLUSH_EVENTS
        )
      )
      return
    end
    result = @batch_events_queue.flush(manual: true)
    @batch_events_queue.kill_thread
    result
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      format(
        LogMessageEnum::ErrorMessages::API_NOT_WORKING,
        file: FILE,
        api_name: ApiMethods::FLUSH_EVENTS,
        exception: e
      )
    )
    false
  end

  def get_goal_type_to_track(options)
    goal_type_to_track = nil
    if !options.key?(:goal_type_to_track)
      if @goal_type_to_track
        goal_type_to_track = @goal_type_to_track
      else
        goal_type_to_track = GOAL_TYPES['ALL']
      end
    elsif GOAL_TYPES.key? options[:goal_type_to_track]
      goal_type_to_track = options[:goal_type_to_track]
    else
      @logger.log(
        LogLevelEnum::ERROR,
        format(
          LogMessageEnum::ErrorMessages::INVALID_GOAL_TYPE,
          file: FILE
        )
      )
    end
    goal_type_to_track
  end

  def is_event_arch_enabled
    return @settings_file.key?('isEventArchEnabled') && @settings_file['isEventArchEnabled']
  end
end

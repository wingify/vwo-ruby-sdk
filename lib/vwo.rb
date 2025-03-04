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
require_relative 'vwo/utils/data_location_manager'
require_relative 'vwo/utils/log_message'
require_relative 'vwo/constants'
require_relative 'vwo/core/variation_decider'
require_relative 'vwo/services/batch_events_dispatcher'
require_relative 'vwo/services/batch_events_queue'
require_relative 'vwo/services/usage_stats'

# VWO main file
class VWO
  attr_accessor :is_instance_valid, :logging, :settings_file_manager, :variation_decider
  attr_reader :usage_stats

  include Enums
  include Utils::Validations
  include Utils::Feature
  include Utils::CustomDimensions
  include Utils::Campaign
  include Utils::Impression
  include Utils::Utility
  include VWO::Utils
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
    @logger = Utils::Logger
    @logger.set_api_name(ApiMethods::LAUNCH)
    options = convert_to_symbol_hash(options)
    @is_opted_out = false
    @account_id = account_id
    @sdk_key = sdk_key
    @user_storage = user_storage
    @is_development_mode = is_development_mode
    @logging = VWO::Logger.get_instance(logger)
    @logging.instance.level = options[:log_level] if (0..5).include?(options[:log_level])
    usage_stats = {}

    usage_stats[:cl] = 1 if logger
    usage_stats[:ll] = 1 if options[:log_level]
    usage_stats[:ss] = 1 if @user_storage
    usage_stats[:ig] = 1 if options.key?(:integrations)
    usage_stats[:eb] = 1 if options.key?(:batch_events)

    unless validate_sdk_config?(@user_storage, is_development_mode, ApiMethods::LAUNCH)
      @is_instance_valid = false
      return
    end

    @settings_file_manager = VWO::Services::SettingsFileManager.new(@account_id, @sdk_key)
    unless valid_settings_file?(get_settings(settings_file))
      @logger.log(
        LogLevelEnum::ERROR,
        'SETTINGS_FILE_CORRUPTED',
        {
          '{file}' => FILE
        }
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
          'CONFIG_PARAMETER_INVALID',
          {
            '{file}' => FILE,
            '{parameter}' => 'goal_type_to_track',
            '{type}' => 'string(REVENUE, CUSTOM, ALL)',
            '{api}' => 'init'
          }
        )
        @is_instance_valid = false
        return
      end
    else
      @goal_type_to_track = 'ALL'
    end

    @is_instance_valid = true
    @config = VWO::Services::SettingsFileProcessor.new(get_settings)

    # Process the settings file
    @config.process_settings_file
    @settings_file = @config.get_settings_file
    DataLocationManager.get_instance.set_settings(@settings_file)
    GetAccountFlags.get_instance.set_settings(@settings_file)
    @usage_stats = VWO::Services::UsageStats.new(usage_stats, @is_development_mode)

    if options.key?(:batch_events)
      if options[:batch_events].is_a?(Hash)
        unless valid_batch_event_settings(options[:batch_events], ApiMethods::LAUNCH)
          @is_instance_valid = false
          return
        end
        @batch_event_dispatcher = VWO::Services::BatchEventsDispatcher.new(@is_development_mode)

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
          'CONFIG_PARAMETER_INVALID',
          {
            '{file}' => FILE,
            '{parameter}' => 'batch_events',
            '{type}' => 'hash',
            '{api}' => 'init'
          }
        )
        @is_instance_valid = false
        return
      end
    end

    # Assign VariationDecider to VWO
    @variation_decider = VWO::Core::VariationDecider.new(@settings_file, user_storage, options)

    # Assign event dispatcher
    @event_dispatcher = VWO::Services::EventDispatcher.new(is_development_mode)

    # Successfully initialized VWO SDK
    @logger.log(
      LogLevelEnum::INFO,
      'SDK_INITIALIZED',
      { '{file}' => FILE }
    )
  end

  def dispatcher(events, callback)
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
    @logger.set_api_name(ApiMethods::GET_AND_UPDATE_SETTINGS_FILE)
    return false if opted_out?(ApiMethods::GET_AND_UPDATE_SETTINGS_FILE)

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        'CONFIG_CORRUPTED',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::GET_AND_UPDATE_SETTINGS_FILE
        }
      )
      return false
    end

    latest_settings = @settings_file_manager.get_settings_file(true)
    latest_settings = JSON.parse(latest_settings)
    if latest_settings == @settings_file
      @logger.log(
        LogLevelEnum::DEBUG,
        'SETTINGS_FILE_PROCESSED',
        {
          '{file}' => FILE,
          '{accountId}' => @settings_file['accountId']
        }
      )
    end

    @config.update_settings_file(latest_settings)
    @settings_file = @config.get_settings_file
    @settings_file
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      "({file}): {api} API error: #{e.message}",
      {
        '{file}' => FILE,
        '{api}' => ApiMethods::GET_AND_UPDATE_SETTINGS_FILE
      }
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
    @logger.set_api_name(ApiMethods::ACTIVATE)
    return nil if opted_out?(ApiMethods::ACTIVATE)

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        'CONFIG_CORRUPTED',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::ACTIVATE
        }
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
        'API_BAD_PARAMETERS',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::ACTIVATE
        }
      )
      return
    end

    # Get the campaign settings
    campaign = get_campaign(@settings_file, campaign_key)

    # Validate campaign
    unless campaign && campaign['status'] == STATUS_RUNNING
      # Log Campaign as invalid
      @logger.log(
        LogLevelEnum::WARNING,
        'CAMPAIGN_NOT_RUNNING',
        {
          '{file}' => FILE,
          '{campaignKey}' => campaign_key,
          '{api}' => ApiMethods::ACTIVATE
        }
      )
      return
    end

    # Get campaign type
    campaign_type = campaign['type']

    # Validate valid api call
    if campaign_type != CampaignTypes::VISUAL_AB
      @logger.log(
        LogLevelEnum::ERROR,
        'API_NOT_APPLICABLE',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::ACTIVATE,
          '{userId}' => user_id,
          '{campaignKey}' => campaign_key,
          '{campaignType}' => campaign_type
        }
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
    return if variation.nil?

    if eligible_to_send_impression?
      if defined?(@batch_events)
        impression = create_bulk_event_impression(
          @settings_file,
          campaign['id'],
          variation['id'],
          user_id, nil, nil, nil,
          options
        )
        @batch_events_queue.enqueue(impression)
      elsif event_arch_enabled?
        properties = get_events_base_properties(@settings_file, EventEnum::VWO_VARIATION_SHOWN, @usage_stats.usage_stats)
        payload = get_track_user_payload_data(@settings_file, user_id, EventEnum::VWO_VARIATION_SHOWN, campaign['id'], variation['id'])
        @event_dispatcher.dispatch_event_arch_post(properties, payload, options)
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
        main_keys = { 'campaignId' => campaign['id'], 'variationId' => variation['id'] }
        @event_dispatcher.dispatch(impression, main_keys, EVENTS::TRACK_USER)
      end
    else
      @logger.log(
        LogLevelEnum::INFO,
        'CAMPAIGN_USER_ALREADY_TRACKED',
        {
          '{file}' => FILE,
          '{userId}' => user_id,
          '{campaignKey}' => campaign_key,
          '{api}' => ApiMethods::ACTIVATE
        }
      )
    end
    variation['name']
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      "({file}): {api} API error: #{e.message}",
      {
        '{file}' => FILE,
        '{api}' => ApiMethods::ACTIVATE
      }
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
    @logger.set_api_name(ApiMethods::GET_VARIATION_NAME)
    return nil if opted_out?(ApiMethods::GET_VARIATION_NAME)

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        'CONFIG_CORRUPTED',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::GET_VARIATION_NAME
        }
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
        'API_BAD_PARAMETERS',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::GET_VARIATION_NAME
        }
      )
      return
    end

    # Get the campaign settings
    campaign = get_campaign(@settings_file, campaign_key)

    # Validate campaign
    if campaign.nil? || campaign['status'] != STATUS_RUNNING
      @logger.log(
        LogLevelEnum::WARNING,
        'CAMPAIGN_NOT_RUNNING',
        {
          '{file}' => FILE,
          '{campaignKey}' => campaign_key,
          '{api}' => ApiMethods::GET_VARIATION_NAME
        }
      )
      return
    end

    campaign_type = campaign['type']

    if campaign_type == CampaignTypes::FEATURE_ROLLOUT
      @logger.log(
        LogLevelEnum::ERROR,
        'API_NOT_APPLICABLE',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::GET_VARIATION_NAME,
          '{userId}' => user_id,
          '{campaignKey}' => campaign_key,
          '{campaignType}' => campaign_type
        }
      )
      return
    end

    case campaign_type
    when CampaignTypes::FEATURE_ROLLOUT
      @logger.log(
        LogLevelEnum::ERROR,
        'API_NOT_APPLICABLE',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::GET_VARIATION_NAME,
          '{userId}' => user_id,
          '{campaignKey}' => campaign_key,
          '{campaignType}' => campaign_type
        }
      )
      return
    end

    variation = @variation_decider.get_variation(user_id, campaign, ApiMethods::GET_VARIATION_NAME, campaign_key, custom_variables, variation_targeting_variables)

    # Check if variation_name has been assigned
    return unless valid_value?(variation)

    variation['name']
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      "({file}): {api} API error: #{e.message}",
      {
        '{file}' => FILE,
        '{api}' => ApiMethods::GET_VARIATION_NAME
      }
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
  # @param[Hash]                        :options          Contains revenue value and custom variables
  #

  def track(campaign_key, user_id, goal_identifier, options = {})
    @logger.set_api_name(ApiMethods::TRACK)
    return false if opted_out?(ApiMethods::TRACK)

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        'CONFIG_CORRUPTED',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::TRACK
        }
      )
      return false
    end

    options = convert_to_symbol_hash(options)
    revenue_value = options[:revenue_value]
    custom_variables = options[:custom_variables]
    variation_targeting_variables = options[:variation_targeting_variables]
    event_properties = options[:event_properties]
    goal_type_to_track = get_goal_type_to_track(options)

    # Check for valid args
    return false unless valid_track_api_params?(user_id, campaign_key, custom_variables, variation_targeting_variables, goal_type_to_track, goal_identifier)

    # Get campaigns settings
    campaigns = get_campaigns(@settings_file, campaign_key, goal_identifier, goal_type_to_track)

    # Validate campaign
    return nil if campaigns.nil?

    metric_map = {}
    revenue_props = []
    result = {}
    batch_event_data = { 'ev' => [] }
    campaigns.each do |campaign|
      begin
        campaign_type = campaign['type']
        result[campaign['key']] = false

        next unless valid_campaign_for_track_api?(user_id, campaign_key, campaign_type)

        variation = @variation_decider.get_variation(user_id, campaign, ApiMethods::TRACK, campaign['key'], custom_variables, variation_targeting_variables, goal_identifier)

        if variation
          goal = get_campaign_goal(campaign, goal_identifier)
          next unless valid_goal?(goal, campaign, user_id, goal_identifier, revenue_value, event_arch_enabled?)

          revenue_value = nil if goal['type'] == GoalTypes::CUSTOM
          identifiers = get_variation_identifiers(variation)

          next if campaign_goal_already_tracked?(user_id, campaign, identifiers, goal_identifier)

          @variation_decider.update_goal_identifier(user_id, campaign, variation, goal_identifier)
          # set variation at user storage

          if goal['type'] == GoalTypes::REVENUE && revenue_value.nil?
            # mca implementation
            if event_arch_enabled?
              if goal['mca'] != -1
                # Check if eventProperties contain revenueProp for mca != -1
                if event_properties.nil?
                # Log error if revenueProp is not found in eventProperties
                  @logger.log(
                    LogLevelEnum::ERROR,
                    'Revenue property not found in event properties for revenue goal',
                    {
                      '{file}' => FILE,
                      '{api}' => ApiMethods::TRACK,
                      '{userId}' => user_id,
                      '{goalIdentifier}' => goal_identifier,
                      '{campaignKey}' => campaign['key']
                    }
                  )
                  result[campaign['key']] = false
                  next
                end
              elsif goal['type'] == GoalTypes::REVENUE && goal['mca'] == -1
                # Check if revenueProp is defined but not found in eventProperties
                if goal['revenueProp'] && event_properties.nil?
                  # Log error if revenueProp is defined but not found in eventProperties
                  @logger.log(
                    LogLevelEnum::ERROR,
                    'Revenue property defined but not found in event properties for revenue goal',
                    {
                      '{file}' => FILE,
                      '{api}' => ApiMethods::TRACK,
                      '{userId}' => user_id,
                      '{goalIdentifier}' => goal_identifier,
                      '{campaignKey}' => campaign['key']
                    }
                  )
                  result[campaign['key']] = false
                  next
                end
              end
            end
          end
          if defined?(@batch_events)
            if event_arch_enabled?
              if goal['type'] == GoalTypes::REVENUE && goal['revenueProp'] && event_properties && event_properties.key?(goal['revenueProp'])
                revenue_value = event_properties[goal['revenueProp']]
              end
            end
            impression = create_bulk_event_impression(@settings_file, campaign['id'], variation['id'], user_id, goal['id'], revenue_value, event_properties, options)
            @batch_events_queue.enqueue(impression)
          elsif event_arch_enabled?
            metric_map[campaign['id']] = goal['id']
            revenue_props << goal['revenueProp'] if goal['type'] == GoalTypes::REVENUE && !(revenue_props.include? goal['revenueProp'])
          elsif campaigns.count == 1
            impression = create_impression(@settings_file, campaign['id'], variation['id'], user_id, @sdk_key, goal['id'], revenue_value)
            main_keys = { 'campaignId' => campaign['id'], 'variationId' => variation['id'], 'goalId' => goal['id'] }
            @event_dispatcher.dispatch(impression, main_keys, EVENTS::TRACK_GOAL)
          else
            batch_event_data['ev'] << create_bulk_event_impression(@settings_file, campaign['id'], variation['id'], user_id, goal['id'], revenue_value, nil, options)
          end
          result[campaign['key']] = true
          next
        end
      rescue StandardError => e
        @logger.log(
          LogLevelEnum::ERROR,
          "({file}): {api} API error: #{e.message}",
          {
            '{file}' => FILE,
            '{api}' => ApiMethods::TRACK
          }
        )
      end
    end

    if event_arch_enabled?
      properties = get_events_base_properties(@settings_file, goal_identifier)
      payload = get_track_goal_payload_data(@settings_file, user_id, goal_identifier, revenue_value, metric_map, revenue_props, event_properties)
      @event_dispatcher.dispatch_event_arch_post(properties, payload, options)
    elsif batch_event_data['ev'].count != 0
      paramters = get_batch_event_query_params(@settings_file['accountId'], @sdk_key, @usage_stats.usage_stats)
      batch_events_dispatcher = VWO::Services::BatchEventsDispatcher.new(@is_development_mode)
      return nil unless batch_events_dispatcher.dispatch(batch_event_data, nil, paramters)
    end

    return nil if result.length == 0

    result
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      "({file}): {api} API error: #{e.message}",
      {
        '{file}' => FILE,
        '{api}' => ApiMethods::TRACK
      }
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
    @logger.set_api_name(ApiMethods::IS_FEATURE_ENABLED)
    return false if opted_out?(ApiMethods::IS_FEATURE_ENABLED)

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        'CONFIG_CORRUPTED',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::IS_FEATURE_ENABLED
        }
      )
      return false
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
        'API_BAD_PARAMETERS',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::IS_FEATURE_ENABLED
        }
      )
      return false
    end

    # Get the campaign settings
    campaign = get_campaign(@settings_file, campaign_key)

    # Validate campaign
    unless campaign && campaign['status'] == STATUS_RUNNING
      # log error
      @logger.log(
        LogLevelEnum::WARNING,
        'CAMPAIGN_NOT_RUNNING',
        {
          '{file}' => FILE,
          '{campaignKey}' => campaign_key,
          '{api}' => ApiMethods::IS_FEATURE_ENABLED
        }
      )
      return false
    end

    # Validate campaign_type
    campaign_type = campaign['type']

    if campaign_type == CampaignTypes::VISUAL_AB
      @logger.log(
        LogLevelEnum::ERROR,
        'API_NOT_APPLICABLE',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::IS_FEATURE_ENABLED,
          '{userId}' => user_id,
          '{campaignKey}' => campaign_key,
          '{campaignType}' => campaign_type
        }
      )
      return false
    end

    # Get variation
    variation = @variation_decider.get_variation(user_id, campaign, ApiMethods::IS_FEATURE_ENABLED, campaign_key, custom_variables, variation_targeting_variables)

    # If no variation, did not become part of feature_test/rollout
    return false unless variation

    # if campaign type is feature_test Send track call to server

    if eligible_to_send_impression?
      if defined?(@batch_events)
        impression = create_bulk_event_impression(
          @settings_file,
          campaign['id'],
          variation['id'],
          user_id, nil, nil, nil,
          options
        )
        @batch_events_queue.enqueue(impression)
      elsif event_arch_enabled?
        properties = get_events_base_properties(@settings_file, EventEnum::VWO_VARIATION_SHOWN, @usage_stats.usage_stats)
        payload = get_track_user_payload_data(@settings_file, user_id, EventEnum::VWO_VARIATION_SHOWN, campaign['id'], variation['id'])
        @event_dispatcher.dispatch_event_arch_post(properties, payload, options)
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

        main_keys = { 'campaignId' => impression[:experiment_id] }
        @event_dispatcher.dispatch(impression, main_keys, EVENTS::TRACK_USER)
      end

    else
      @logger.log(
        LogLevelEnum::INFO,
        'CAMPAIGN_USER_ALREADY_TRACKED',
        {
          '{file}' => FILE,
          '{userId}' => user_id,
          '{campaignKey}' => campaign_key,
          '{api}' => ApiMethods::IS_FEATURE_ENABLED
        }
      )
    end
    result = if campaign_type == CampaignTypes::FEATURE_ROLLOUT
               true
             else
               variation['isFeatureEnabled']
             end

    if result
      @logger.log(
        LogLevelEnum::INFO,
        'FEATURE_STATUS',
        {
          '{file}' => FILE,
          '{userId}' => user_id,
          '{campaignKey}' => campaign_key,
          '{status}' => 'enabled'
        }
      )
    else
      @logger.log(
        LogLevelEnum::INFO,
        'FEATURE_STATUS',
        {
          '{file}' => FILE,
          '{userId}' => user_id,
          '{campaignKey}' => campaign_key,
          '{status}' => 'disabled'
        }
      )
    end

    result
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      "({file}): {api} API error: #{e.message}",
      {
        '{file}' => FILE,
        '{api}' => ApiMethods::IS_FEATURE_ENABLED
      }
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
    @logger.set_api_name(ApiMethods::GET_FEATURE_VARIABLE_VALUE)
    return nil if opted_out?(ApiMethods::GET_FEATURE_VARIABLE_VALUE)

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        'CONFIG_CORRUPTED',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::GET_FEATURE_VARIABLE_VALUE
        }
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
        'API_BAD_PARAMETERS',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::GET_FEATURE_VARIABLE_VALUE
        }
      )
      return
    end

    # Get the campaign settings
    campaign = get_campaign(@settings_file, campaign_key)

    # Validate campaign
    unless campaign && campaign['status'] == STATUS_RUNNING
      # log error
      @logger.log(
        LogLevelEnum::WARNING,
        'CAMPAIGN_NOT_RUNNING',
        {
          '{file}' => FILE,
          '{campaignKey}' => campaign_key,
          '{api}' => ApiMethods::GET_FEATURE_VARIABLE_VALUE
        }
      )
      return
    end

    campaign_type = campaign['type']

    if campaign_type == CampaignTypes::VISUAL_AB
      @logger.log(
        LogLevelEnum::ERROR,
        'API_NOT_APPLICABLE',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::GET_FEATURE_VARIABLE_VALUE,
          '{userId}' => user_id,
          '{campaignKey}' => campaign_key,
          '{campaignType}' => campaign_type
        }
      )
      return
    end

    variation = @variation_decider.get_variation(user_id, campaign, ApiMethods::GET_FEATURE_VARIABLE_VALUE, campaign_key, custom_variables, variation_targeting_variables)

    # Check if variation has been assigned to user
    return unless variation

    case campaign_type
    when CampaignTypes::FEATURE_ROLLOUT
      variables = campaign['variables']
    when CampaignTypes::FEATURE_TEST
      if !variation['isFeatureEnabled']
        @logger.log(
          LogLevelEnum::INFO,
          'FEATURE_STATUS',
          {
            '{file}' => FILE,
            '{userId}' => user_id,
            '{campaignKey}' => campaign_key,
            '{status}' => 'disabled'
          }
        )
        variation = get_control_variation(campaign)
      else
        @logger.log(
          LogLevelEnum::INFO,
          'FEATURE_STATUS',
          {
            '{file}' => FILE,
            '{userId}' => user_id,
            '{campaignKey}' => campaign_key,
            '{status}' => 'enabled'
          }
        )
      end
      variables = variation['variables']
    end
    variable = get_variable(variables, variable_key)

    unless variable
      # Log variable not found
      @logger.log(
        LogLevelEnum::INFO,
        'FEATURE_VARIABLE_DEFAULT_VALUE',
        {
          '{file}' => FILE,
          '{variableKey}' => variable_key,
          '{variationName}' => variation['name']
        }
      )
      return
    end

    @logger.log(
      LogLevelEnum::INFO,
      'FEATURE_VARIABLE_VALUE',
      {
        '{file}' => FILE,
        '{variableKey}' => variable_key,
        '{variableValue}' => variable['value'],
        '{campaignKey}' => campaign_key,
        '{userId}' => user_id
      }
    )
    get_type_casted_feature_value(variable['value'], variable['type'])
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      "({file}): {api} API error: #{e.message}",
      {
        '{file}' => FILE,
        '{api}' => ApiMethods::GET_FEATURE_VARIABLE_VALUE
      }
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
    @logger.set_api_name(ApiMethods::PUSH)
    return {} if opted_out?(ApiMethods::PUSH)

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        'CONFIG_CORRUPTED',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::PUSH
        }
      )
      return {}
    end

    # Argument reshuffling.
    custom_dimension_map = {}
    if user_id.nil? || tag_key.is_a?(Hash)
      custom_dimension_map = convert_to_symbol_hash(tag_key)
      user_id = tag_value
    else
      custom_dimension_map[tag_key.to_sym] = tag_value
    end

    unless (valid_string?(tag_key) || valid_hash?(tag_key)) && valid_string?(user_id)
      @logger.log(
        LogLevelEnum::ERROR,
        'API_BAD_PARAMETERS',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::PUSH
        }
      )
      return {}
    end

    result = {}
    custom_dimension_map.each do |tagkey, tagvalue|
      if !tagkey.is_a?(Symbol) || !tagvalue.is_a?(String)
        custom_dimension_map.delete(tagkey)
        result[tagkey] = false
        next
      end

      if tagkey.length > PushApi::TAG_KEY_LENGTH || tagkey.length == 0
        @logger.log(
          LogLevelEnum::ERROR,
          'TAG_KEY_LENGTH_EXCEEDED',
          {
            '{file}' => FILE,
            '{userId}' => user_id,
            '{tagKey}' => tagkey
          }
        )
        custom_dimension_map.delete(tagkey)
        result[tagkey] = false
        next
      end

      next unless tagvalue.length > PushApi::TAG_VALUE_LENGTH || tagvalue.length == 0

      @logger.log(
        LogLevelEnum::ERROR,
        'TAG_VALUE_LENGTH_EXCEEDED',
        {
          '{file}' => FILE,
          '{userId}' => user_id,
          '{tagKey}' => tagkey,
          '{tagValue}' => tagvalue
        }
      )
      custom_dimension_map.delete(tagkey)
      result[tagkey] = false
    end

    if custom_dimension_map.count == 0
      @logger.log(
        LogLevelEnum::ERROR,
        'API_BAD_PARAMETERS',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::PUSH
        }
      )
      return result
    end

    if defined?(@batch_events)
      custom_dimension_map.each do |tagkey, tagvalue|
        impression = get_batch_event_url_params(@settings_file, tagkey, tagvalue, user_id)
        @batch_events_queue.enqueue(impression)
      end
      resp = true
    elsif event_arch_enabled?
      properties = get_events_base_properties(@settings_file, EventEnum::VWO_SYNC_VISITOR_PROP)
      payload = get_push_payload_data(@settings_file, user_id, EventEnum::VWO_SYNC_VISITOR_PROP, custom_dimension_map)
      resp = @event_dispatcher.dispatch_event_arch_post(properties, payload)
    elsif custom_dimension_map.count == 1
      custom_dimension_map.each do |tagkey, tagvalue|
        impression = get_url_params(@settings_file, tagkey, tagvalue, user_id, @sdk_key)
        main_keys = { 'tags' => impression['tags'] }
        result[tagkey] = @event_dispatcher.dispatch(impression, main_keys, EVENTS::PUSH)
      end
      resp = true
    else
      batch_event_data = { 'ev' => [] }
      custom_dimension_map.each do |tagkey, tagvalue|
        batch_event_data['ev'] << get_batch_event_url_params(@settings_file, tagkey, tagvalue, user_id)
      end
      paramters = get_batch_event_query_params(@settings_file['accountId'], @sdk_key, @usage_stats.usage_stats)
      batch_events_dispatcher = VWO::Services::BatchEventsDispatcher.new(@is_development_mode)
      resp = batch_events_dispatcher.dispatch(batch_event_data, nil, paramters)
    end

    prepare_push_response(custom_dimension_map, resp, result)
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      "({file}): push API error: #{e.message}",
      { '{file}' => FILE }
    )
    false
  end

  def eligible_to_send_impression?
    !@user_storage || !@variation_decider.has_stored_variation
  end

  # Manually flush impression events to VWO which are queued in batch queue as per batchEvents config
  # @return[bool]
  def flush_events
    @logger.set_api_name(ApiMethods::FLUSH_EVENTS)
    return false if opted_out?(ApiMethods::FLUSH_EVENTS)

    unless @is_instance_valid
      @logger.log(
        LogLevelEnum::ERROR,
        'CONFIG_CORRUPTED',
        {
          '{file}' => FILE,
          '{api}' => ApiMethods::FLUSH_EVENTS
        }
      )
      return false
    end
    result = false
    if defined?(@batch_events) && !@batch_events_queue.nil?
      result = @batch_events_queue.flush(manual: true)
      @batch_events_queue.kill_thread
    end
    result
  rescue StandardError => e
    @logger.log(
      LogLevelEnum::ERROR,
      "({file}): {api} API error: #{e.message}",
      {
        '{file}' => FILE,
        '{api}' => ApiMethods::FLUSH_EVENTS
      }
    )
    false
  end

  def get_goal_type_to_track(options)
    goal_type_to_track = nil
    if !options.key?(:goal_type_to_track)
      goal_type_to_track = @goal_type_to_track || GOAL_TYPES['ALL']
    elsif GOAL_TYPES.key? options[:goal_type_to_track]
      goal_type_to_track = options[:goal_type_to_track]
    else
      @logger.log(
        LogLevelEnum::ERROR,
        'CONFIG_PARAMETER_INVALID',
        {
          '{file}' => FILE,
          '{parameter}' => 'goal_type_to_track',
          '{type}' => 'string(REVENUE, CUSTOM, ALL)',
          '{api}' => 'init'
        }
      )
    end
    goal_type_to_track
  end

  # Manually opting out of VWO SDK, No tracking will happen
  #
  # return[bool]
  #
  def set_opt_out
    @logger.set_api_name(ApiMethods::OPT_OUT)
    @logger.log(
      LogLevelEnum::INFO,
      'OPT_OUT_API_CALLED',
      {
        '{file}' => FILE
      }
    )
    if defined?(@batch_events) && !@batch_events_queue.nil?
      @batch_events_queue.flush(manual: true)
      @batch_events_queue.kill_thread
    end

    @is_opted_out = true
    @settings_file = nil
    @user_storage = nil
    @event_dispatcher = nil
    @variation_decider = nil
    @config = nil
    @usage_stats = nil
    @batch_event_dispatcher = nil
    @batch_events_queue = nil
    @batch_events = nil

    @is_opted_out
  end

  # Check if VWO SDK is manually opted out
  # @param[String]          :api_name              api_name is used in logging
  # @return[bool]
  def opted_out?(api_name)
    if @is_opted_out
      @logger.log(
        LogLevelEnum::INFO,
        'API_NOT_ENABLED',
        {
          '{file}' => FILE,
          '{api}' => api_name
        }
      )
    end
    @is_opted_out
  end

  def event_arch_enabled?
    @settings_file.key?('isEventArchEnabled') && @settings_file['isEventArchEnabled']
  end
end

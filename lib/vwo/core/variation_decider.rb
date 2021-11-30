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

require_relative '../logger'
require_relative '../enums'
require_relative '../utils/campaign'
require_relative '../services/segment_evaluator'
require_relative '../utils/validations'
require_relative 'bucketer'
require_relative '../constants'
require_relative '../services/hooks_manager'
require_relative '../utils/uuid'

class VWO
  module Core
    class VariationDecider
      attr_reader :user_storage_service, :has_stored_variation, :hooks_manager

      include VWO::Enums
      include VWO::Utils::Campaign
      include VWO::Utils::Validations
      include VWO::CONSTANTS
      include VWO::Utils::UUID

      FILE = FileNameEnum::VariationDecider

      # Initializes various services
      # @param[Hash] -   Settings file
      # @param[Class] -  Class instance having the capability of
      #                  get and save.
      def initialize(settings_file, user_storage_service = nil, options = {})
        @logger = VWO::Logger.get_instance
        @user_storage_service = user_storage_service
        @bucketer = VWO::Core::Bucketer.new
        @settings_file = settings_file
        @segment_evaluator = VWO::Services::SegmentEvaluator.new
        @hooks_manager = VWO::Services::HooksManager.new(options)
      end

      # Returns variation for the user for the passed campaign-key
      # Check if Whitelisting is applicable, evaluate it, if any eligible variation is found,return, otherwise skip it
      # Check in User Storage, if user found, validate variation and return
      # Otherwise, proceed with variation assignment logic
      #
      #
      # @param[String]          :user_id             The unique ID assigned to User
      # @param[Hash]            :campaign            Campaign hash itself
      # @param[String]          :campaign_key        The unique ID of the campaign passed
      # @param[String]          :goal_identifier     The unique campaign's goal identifier
      # @return[String,String]                       ({variation_id, variation_name}|Nil): Tuple of
      #                                              variation_id and variation_name if variation allotted, else nil

      def get_variation(user_id, campaign, api_name, campaign_key, custom_variables = {}, variation_targeting_variables = {}, goal_identifier = '')
        campaign_key ||= campaign['key']

        return unless campaign

        is_campaign_part_of_group = @settings_file && is_part_of_group(@settings_file, campaign["id"])

        @has_stored_variation = false
        decision = {
          :campaign_id => campaign['id'],
          :campaign_key => campaign_key,
          :campaign_type => campaign['type'],
        # campaign segmentation conditions
          :custom_variables => custom_variables,
        # event name
          :event => Hooks::DECISION_TYPES['CAMPAIGN_DECISION'],
        # goal tracked in case of track API
          :goal_identifier => goal_identifier,
        # campaign whitelisting flag
          :is_forced_variation_enabled => campaign['isForcedVariationEnabled'] ? campaign['isForcedVariationEnabled'] : false,
          :sdk_version => SDK_VERSION,
        # API name which triggered the event
          :source => api_name,
        # Passed in API
          :user_id => user_id,
        # Campaign Whitelisting conditions
          :variation_targeting_variables => variation_targeting_variables,
          :is_user_whitelisted => false,
          :from_user_storage_service => false,
          :is_feature_enabled => true,
        # VWO generated UUID based on passed UserId and Account ID
          :vwo_user_id => generator_for(user_id, @settings_file['accountId'])
        }

        if campaign.has_key?("name")
          decision[:campaign_name] = campaign['name']
        end

        if is_campaign_part_of_group
          group_id = @settings_file["campaignGroups"][campaign["id"].to_s]
          decision[:group_id] = group_id
          group_name = @settings_file["groups"][group_id.to_s]["name"]
          decision[:group_name] = group_name
        end

        # evaluate whitelisting
        variation = get_variation_if_whitelisting_passed(user_id, campaign, variation_targeting_variables, api_name, decision, true)
        return variation if variation && variation['name']

        user_campaign_map = get_user_storage(user_id, campaign_key)
        variation = get_stored_variation(user_id, campaign_key, user_campaign_map) if valid_hash?(user_campaign_map)

        if variation
          variation = variation.dup  # deep copy
        end

        if variation
          if valid_string?(user_campaign_map['goal_identifier']) && api_name == ApiMethods::TRACK
            variation['goal_identifier'] = user_campaign_map['goal_identifier']
          end
          @has_stored_variation = true
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::GOT_STORED_VARIATION,
              file: FILE,
              campaign_key: campaign_key,
              user_id: user_id,
              variation_name: variation['name']
            )
          )
          decision[:from_user_storage_service] = !!variation['name']
          if variation
            if campaign['type'] == CampaignTypes::VISUAL_AB || campaign['type'] == CampaignTypes::FEATURE_TEST
              decision[:variation_name] = variation['name']
              decision[:variation_id] = variation['id']
              if campaign['type'] == CampaignTypes::FEATURE_TEST
                decision[:is_feature_enabled] = variation['isFeatureEnabled']
              end
            end
            @hooks_manager.execute(decision)
          end
          return variation
        else
          @logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::NO_STORED_VARIATION,
              file: FILE,
              campaign_key: campaign_key,
              user_id: user_id
            )
          )

          if ([ApiMethods::TRACK, ApiMethods::GET_VARIATION_NAME, ApiMethods::GET_FEATURE_VARIABLE_VALUE].include? api_name) && @user_storage_service
            @logger.log(
              LogLevelEnum::DEBUG,
              format(
                LogMessageEnum::DebugMessages::CAMPAIGN_NOT_ACTIVATED,
                file: FILE,
                campaign_key: campaign_key,
                user_id: user_id,
                api_name: api_name
              )
            )

            @logger.log(
              LogLevelEnum::INFO,
              format(
                LogMessageEnum::InfoMessages::CAMPAIGN_NOT_ACTIVATED,
                file: FILE,
                campaign_key: campaign_key,
                user_id: user_id,
                api_name: api_name,
                reason: api_name == ApiMethods::TRACK ? 'track it' : 'get the decision/value'
              )
            )
            return
          end
        end

        # Pre-segmentation
        is_presegmentation = check_presegmentation(campaign, user_id, custom_variables, api_name)
        is_presegmentation_and_traffic_passed = is_presegmentation && @bucketer.user_part_of_campaign?(user_id, campaign)
        unless is_presegmentation_and_traffic_passed
          return nil
        end

        if is_presegmentation_and_traffic_passed && is_campaign_part_of_group
          group_campaigns = get_group_campaigns(@settings_file, group_id)

          if group_campaigns
            is_any_campaign_whitelisted_or_stored = check_whitelisting_or_storage_for_grouped_campaigns(user_id, campaign, group_campaigns, group_name, variation_targeting_variables, true)

            if is_any_campaign_whitelisted_or_stored
              @logger.log(
                LogLevelEnum::INFO,
                format(
                  LogMessageEnum::InfoMessages::CALLED_CAMPAIGN_NOT_WINNER,
                  file: FILE,
                  campaign_key: campaign_key,
                  user_id: user_id,
                  group_name: group_name
                )
              )
              return nil
            end

            eligible_campaigns = get_eligible_campaigns(user_id, group_campaigns, campaign, custom_variables)
            non_eligible_campaigns_key = get_non_eligible_campaigns_key(eligible_campaigns, group_campaigns)

            @logger.log(
              LogLevelEnum::DEBUG,
              format(
                LogMessageEnum::DebugMessages::GOT_ELIGIBLE_CAMPAIGNS,
                file: FILE,
                user_id: user_id,
                eligible_campaigns_key: get_eligible_campaigns_key(eligible_campaigns).join(","),
                ineligible_campaigns_log_text: non_eligible_campaigns_key ? ("campaigns:" + non_eligible_campaigns_key.join("'")) : "no campaigns",
                group_name: group_name
              )
            )

            @logger.log(
              LogLevelEnum::INFO,
              format(
                LogMessageEnum::InfoMessages::GOT_ELIGIBLE_CAMPAIGNS,
                file: FILE,
                user_id: user_id,
                no_of_eligible_campaigns: eligible_campaigns.length,
                no_of_group_campaigns: group_campaigns.length,
                group_name: group_name
              )
            )

            winner_campaign = get_winner_campaign(user_id, eligible_campaigns, group_id)
            @logger.log(
              LogLevelEnum::INFO,
              format(
                LogMessageEnum::InfoMessages::GOT_WINNER_CAMPAIGN,
                file: FILE,
                user_id: user_id,
                campaign_key: winner_campaign["key"],
                group_name: group_name
              )
            )

            if winner_campaign && winner_campaign["id"] == campaign["id"]
              variation = get_variation_allotted(user_id, campaign, true)
              if variation && variation['name']
                save_user_storage(user_id, campaign_key, campaign['type'], variation['name'], goal_identifier, true) if variation['name']
              else
                return nil
              end
            else
              @logger.log(
                LogLevelEnum::INFO,
                format(
                  LogMessageEnum::InfoMessages::CALLED_CAMPAIGN_NOT_WINNER,
                  file: FILE,
                  campaign_key: campaign_key,
                  user_id: user_id,
                  group_name: group_name
                )
              )
              return nil
            end
          end
        end

        if variation.nil?
          variation = get_variation_allotted(user_id, campaign)

          if variation && variation['name']
            save_user_storage(user_id, campaign_key, campaign['type'], variation['name'], goal_identifier) if variation['name']
          else
            @logger.log(
              LogLevelEnum::INFO,
              format(LogMessageEnum::InfoMessages::NO_VARIATION_ALLOCATED, file: FILE, campaign_key: campaign_key, user_id: user_id)
            )
          end

        end

        if variation
          if campaign['type'] == CampaignTypes::VISUAL_AB || campaign['type'] == CampaignTypes::FEATURE_TEST
            decision[:variation_name] = variation['name']
            decision[:variation_id] = variation['id']
            if campaign['type'] == CampaignTypes::FEATURE_TEST
              decision[:is_feature_enabled] = variation['isFeatureEnabled']
            end
          end
          @hooks_manager.execute(decision)
        end
        variation
      end

      # Returns the Variation Alloted for required campaign
      #
      # @param[String]  :user_id      The unique key assigned to User
      # @param[Hash]    :campaign     Campaign hash for Unique campaign key
      #
      # @return[Hash]

      def get_variation_allotted(user_id, campaign, disable_logs = false)
        unless valid_value?(user_id)
          @logger.log(
            LogLevelEnum::ERROR,
            format(LogMessageEnum::ErrorMessages::INVALID_USER_ID, file: FILE, user_id: user_id, method: 'get_variation_alloted')
          )
          return
        end

        if @bucketer.user_part_of_campaign?(user_id, campaign)
          variation = get_variation_of_campaign_for_user(user_id, campaign)
          @logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::GOT_VARIATION_FOR_USER,
              file: FILE,
              variation_name: variation['name'],
              user_id: user_id,
              campaign_key: campaign['key'],
              method: 'get_variation_allotted'
            ),
            disable_logs
          )
          variation
        else
          # not part of campaign
          @logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::USER_NOT_PART_OF_CAMPAIGN,
              file: FILE,
              user_id: user_id,
              campaign_key: nil,
              method: 'get_variation_allotted'
            ),
            disable_logs
          )
          nil
        end
      end

      # Assigns variation to a particular user depending on the campaign PercentTraffic.
      #
      # @param[String]              :user_id      The unique ID assigned to a user
      # @param[Hash]                :campaign     The Campaign of which user is to be made a part of
      # @return[Hash]                         Variation allotted to User

      def get_variation_of_campaign_for_user(user_id, campaign)
        unless campaign
          @logger.log(
            LogLevelEnum::ERROR,
            format(
              LogMessageEnum::ErrorMessages::INVALID_CAMPAIGN,
              file: FILE,
              method: 'get_variation_of_campaign_for_user'
            )
          )
          return nil
        end

        variation = @bucketer.bucket_user_to_variation(user_id, campaign)

        if variation && variation['name']
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::GOT_VARIATION_FOR_USER,
              file: FILE,
              variation_name: variation['name'],
              user_id: user_id,
              campaign_key: campaign['key']
            )
          )
          return variation
        end

        @logger.log(
          LogLevelEnum::INFO,
          format(
            LogMessageEnum::InfoMessages::USER_GOT_NO_VARIATION,
            file: FILE,
            user_id: user_id,
            campaign_key: campaign['key']
          )
        )
        nil
      end

      # If UserStorageService is provided, save the assigned variation
      #
      # @param[String]              :user_id            Unique user identifier
      # @param[String]              :campaign_key       Unique campaign identifier
      # @param[String]              :variation_name     Variation identifier
      # @param[String]              :goal_identifier    The unique campaign's goal identifier
      # @param[Boolean]             :disable_logs       optional: disable logs if True
      # @return[Boolean]                                true if found otherwise false

      def save_user_storage(user_id, campaign_key, campaign_type, variation_name, goal_identifier, disable_logs = false)
        unless @user_storage_service
          @logger.log(
            LogLevelEnum::DEBUG,
            format(LogMessageEnum::DebugMessages::NO_USER_STORAGE_SERVICE_SAVE, file: FILE),
            disable_logs
          )
          return false
        end
        new_campaign_user_mapping = {}
        new_campaign_user_mapping['campaign_key'] = campaign_key
        new_campaign_user_mapping['user_id'] = user_id
        new_campaign_user_mapping['variation_name'] = variation_name
        if !goal_identifier.empty?
          new_campaign_user_mapping['goal_identifier'] = goal_identifier
        end

        @user_storage_service.set(new_campaign_user_mapping)

        @logger.log(
          LogLevelEnum::INFO,
          format(LogMessageEnum::InfoMessages::SAVING_DATA_USER_STORAGE_SERVICE, file: FILE, user_id: user_id),
          disable_logs
        )

        @logger.log(
          LogLevelEnum::INFO,
          format(
            LogMessageEnum::InfoMessages::VARIATION_ALLOCATED,
            file: FILE,
            campaign_key: campaign_key,
            user_id: user_id,
            variation_name: variation_name,
            campaign_type: campaign_type
          ),
          disable_logs
        )
        true
      rescue StandardError
        @logger.log(
          LogLevelEnum::ERROR,
          format(LogMessageEnum::ErrorMessages::SAVE_USER_STORAGE_SERVICE_FAILED, file: FILE, user_id: user_id),
          disable_logs
        )
        false
      end

      private

      # Evaluate all the variations in the campaign to find
      #
      # @param[String]  :user_id                            The unique key assigned to User
      # @param[Hash]    :campaign                           Campaign hash for Unique campaign key
      # @param[String]  :api_name                           The key Passed to identify the calling API
      # @param[String]  :campaign_key                       Unique campaign key
      # @param[Hash]    :variation_targeting_variables      Key/value pair of Whitelisting Custom Attributes
      # @param[Boolean] :disable_logs                       optional: disable logs if True
      #
      # @return[Hash]

      def evaluate_whitelisting(user_id, campaign, api_name, campaign_key, variation_targeting_variables = {}, disable_logs = false)
        if variation_targeting_variables.nil?
          variation_targeting_variables = { _vwo_user_id: user_id }
        else
          variation_targeting_variables[:_vwo_user_id] = user_id
        end
        targeted_variations = []

        campaign['variations'].each do |variation|
          segments = get_segments(variation)
          is_valid_segments = valid_value?(segments)
          if is_valid_segments
            if @segment_evaluator.evaluate(campaign_key, user_id, segments, variation_targeting_variables, disable_logs)
              targeted_variations.push(variation)
              status = StatusEnum::PASSED
            else
              status = StatusEnum::FAILED
            end
            @logger.log(
              LogLevelEnum::DEBUG,
              format(
                LogMessageEnum::DebugMessages::SEGMENTATION_STATUS,
                file: FILE,
                campaign_key: campaign_key,
                user_id: user_id,
                status: status,
                custom_variables: variation_targeting_variables,
                variation_name: status == StatusEnum::PASSED ? (campaign['type'] == CampaignTypes::FEATURE_ROLLOUT ? 'and hence becomes part of the rollout' : "for " + variation['name']) : '',
                segmentation_type: SegmentationTypeEnum::WHITELISTING,
                api_name: api_name
              ),
              disable_logs
            )
          else
            @logger.log(
              LogLevelEnum::DEBUG,
              format(
                LogMessageEnum::InfoMessages::SKIPPING_SEGMENTATION,
                file: FILE,
                campaign_key: campaign_key,
                user_id: user_id,
                api_name: api_name,
                variation: variation['name']
              ),
              disable_logs
            )
          end
        end

        if targeted_variations.length > 1
          targeted_variations_deep_clone = Marshal.load(Marshal.dump(targeted_variations))
          scale_variation_weights(targeted_variations_deep_clone)
          current_allocation = 0
          targeted_variations_deep_clone.each do |variation|
            step_factor = get_variation_bucketing_range(variation['weight'])
            if step_factor > 0
              start_range = current_allocation + 1
              end_range = current_allocation + step_factor
              variation['start_variation_allocation'] = start_range
              variation['end_variation_allocation'] = end_range
              current_allocation += step_factor
            else
              variation['start_variation_allocation'] = -1
              variation['end_variation_allocation'] = -1
            end
          end
          whitelisted_variation = @bucketer.get_variation(
            targeted_variations_deep_clone,
            @bucketer.get_bucket_value_for_user(
              user_id,
              campaign
            )
          )
        else
          whitelisted_variation = targeted_variations[0]
        end
        whitelisted_variation
      end

      # It extracts the weights from all the variations inside the campaign
      # and scales them so that the total sum of eligible variations' weights become 100%
      #
      # 1. variations

      def scale_variation_weights(variations)
        total_weight = variations.reduce(0) { |final_weight, variation| final_weight + variation['weight'].to_f }
        if total_weight == 0
          weight = 100 / variations.length
          variations.each do |variation|
            variation['weight'] = weight
          end
        else
          variations.each do |variation|
            variation['weight'] = (variation['weight'] / total_weight) * 100
          end
        end
      end

      def scale_campaigns_weight(campaigns)
        normalize_weight = 100/campaigns.length
        campaigns.each do |campaign|
          campaign['weight'] = normalize_weight
        end
      end
      # Get the UserStorageData after looking up into get method
      # Being provided via UserStorageService
      #
      # @param[String]: Unique user identifier
      # @param[String]: Unique campaign key
      # @param[Boolean] :disable_logs if True
      # @return[Hash|Boolean]: user_storage data

      def get_user_storage(user_id, campaign_key, disable_logs = false)
        unless @user_storage_service
          @logger.log(
            LogLevelEnum::DEBUG,
            format(LogMessageEnum::DebugMessages::NO_USER_STORAGE_SERVICE_LOOKUP, file: FILE),
            disable_logs
          )
          return false
        end

        data = @user_storage_service.get(user_id, campaign_key)
        @logger.log(
          LogLevelEnum::INFO,
          format(
            LogMessageEnum::InfoMessages::LOOKING_UP_USER_STORAGE_SERVICE,
            file: FILE,
            user_id: user_id,
            status: data.nil? ? 'Not Found' : 'Found'
          ),
          disable_logs
        )
        data
      rescue StandardError
        @logger.log(
          LogLevelEnum::ERROR,
          format(LogMessageEnum::ErrorMessages::LOOK_UP_USER_STORAGE_SERVICE_FAILED, file: FILE, user_id: user_id),
          disable_logs
        )
        false
      end

      # If UserStorageService is provided and variation was stored,
      # Get the stored variation
      # @param[String]            :user_id
      # @param[String]            :campaign_key campaign identified
      # @param[Hash]              :user_campaign_map BucketMap consisting of stored user variation
      # @param[Boolean] :disable_logs if True
      #
      # @return[Object, nil]      if found then variation settings object otherwise None

      def get_stored_variation(user_id, campaign_key, user_campaign_map, disable_logs = false)
        return unless user_campaign_map['campaign_key'] == campaign_key

        variation_name = user_campaign_map['variation_name']
        @logger.log(
          LogLevelEnum::DEBUG,
          format(
            LogMessageEnum::DebugMessages::GETTING_STORED_VARIATION,
            file: FILE,
            campaign_key: campaign_key,
            user_id: user_id,
            variation_name: variation_name
          ),
          disable_logs
        )

        get_campaign_variation(
          @settings_file,
          campaign_key,
          variation_name
        )
      end

      # this function check whether pre-segmentation is passed or not
      #
      # @param[String]  :user_id                            The unique key assigned to User
      # @param[Hash]    :campaign                           Campaign hash for Unique campaign key
      # @param[Hash]    :custom_variables                   Key/value pair for segmentation
      # @param[String]  :api_name                           The key Passed to identify the calling API
      # @param[Boolean] :disable_logs                       optional: disable logs if True
      #
      # @return[Boolean]
      def check_presegmentation(campaign, user_id, custom_variables, api_name, disable_logs = false)
        campaign_key = campaign['key']
        segments = get_segments(campaign)
        is_valid_segments = valid_value?(segments)

        if is_valid_segments
          unless custom_variables
            @logger.log(
              LogLevelEnum::INFO,
              format(
                LogMessageEnum::InfoMessages::NO_CUSTOM_VARIABLES,
                file: FILE,
                campaign_key: campaign_key,
                user_id: user_id,
                api_name: api_name
              ),
              disable_logs
            )
            custom_variables = {}
          end
          unless @segment_evaluator.evaluate(campaign_key, user_id, segments, custom_variables, disable_logs)
            @logger.log(
              LogLevelEnum::INFO,
              format(
                LogMessageEnum::InfoMessages::USER_FAILED_SEGMENTATION,
                file: FileNameEnum::SegmentEvaluator,
                user_id: user_id,
                campaign_key: campaign_key,
                custom_variables: custom_variables
              ),
              disable_logs
            )
            return false
          end
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::USER_PASSED_SEGMENTATION,
              file: FileNameEnum::SegmentEvaluator,
              user_id: user_id,
              campaign_key: campaign_key,
              custom_variables: custom_variables
            ),
            disable_logs
          )
        else
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::SKIPPING_SEGMENTATION,
              file: FILE,
              campaign_key: campaign_key,
              user_id: user_id,
              api_name: api_name,
              variation: ''
            ),
            disable_logs
          )
        end
        true
      end

      # Finds and returns eligible campaigns from group_campaigns.
      #
      # @param[String]  :user_id                            The unique key assigned to User
      # @param[Hash]    :called_campaign                    campaign for which api is called
      # @param[Array]   :group_campaigns                    campaigns part of group
      # @param[String]  :custom_variables                   Key/value pair for segmentation
      #
      # @return[Array]
      def get_eligible_campaigns(user_id, group_campaigns, called_campaign, custom_variables)
        eligible_campaigns = []

        group_campaigns.each do |campaign|
          if called_campaign["id"] == campaign["id"] || check_presegmentation(campaign, user_id, custom_variables, '', true) && @bucketer.user_part_of_campaign?(user_id, campaign)
            eligible_campaigns.push(campaign)
          end
        end
        return eligible_campaigns
      end

      # Finds and returns the winner campaign from eligible_campaigns list.
      #
      # @param[String]  :user_id                            The unique key assigned to User
      # @param[Array]   :eligible_campaigns                 campaigns part of group which were eligible to be winner
      #
      # @return[Hash]
      def get_winner_campaign(user_id, eligible_campaigns, group_id)
        if eligible_campaigns.length == 1
          return eligible_campaigns[0]
        end

        eligible_campaigns = scale_campaigns_weight(eligible_campaigns)
        eligible_campaigns = set_campaign_allocation(eligible_campaigns)
        bucket_value = @bucketer.get_bucket_value_for_user(user_id, {}, group_id, true)
        return @bucketer.get_campaign_using_range(bucket_value, eligible_campaigns)
      end

      # Get campaign keys of all eligible Campaigns.
      #
      # @param[Array]   :eligible_campaigns                 campaigns part of group which were eligible to be winner
      #
      # @return[Array]
      def get_eligible_campaigns_key(eligible_campaigns)
        eligible_campaigns_key = []
        eligible_campaigns.each do |campaign|
          eligible_campaigns_key.push(campaign["key"])
        end
        eligible_campaigns_key
      end

      # Get campaign keys of all non eligible Campaigns.
      #
      # @param[Array]   :eligible_campaigns                 campaigns part of group which were eligible to be winner
      # @param[Array]   :group_campaigns                    campaigns part of group
      #
      # @return[Array]
      def get_non_eligible_campaigns_key(eligible_campaigns, group_campaigns)
        non_eligible_campaigns_key = []
        group_campaigns.each do |campaign|
          unless eligible_campaigns.include? campaign
            non_eligible_campaigns_key.push(campaign["key"])
          end
        end
        non_eligible_campaigns_key
      end

      # Checks if any other campaign in groupCampaigns satisfies whitelisting or is in user storage.
      #
      # @param[String]  :user_id                            the unique ID assigned to User
      # @param[Hash]    :called_campaign                    campaign for which api is called
      # @param[Array]   :group_campaigns                    campaigns part of group
      # @param[String]  :group_name                         group name
      # @param[Hash]    :variation_targeting_variables      Key/value pair of Whitelisting Custom Attributes
      # @param[Boolean] :disable_logs                       optional: disable logs if True
      # @return[Boolean]

      def check_whitelisting_or_storage_for_grouped_campaigns(user_id, called_campaign, group_campaigns, group_name, variation_targeting_variables, disable_logs = false)
        group_campaigns.each do |campaign|
          if called_campaign["id"] != campaign["id"]
            targeted_variation = evaluate_whitelisting(
              user_id,
              campaign,
              '',
              campaign["key"],
              variation_targeting_variables,
              true
            )
            if targeted_variation
              @logger.log(
                LogLevelEnum::INFO,
                format(
                  LogMessageEnum::InfoMessages::OTHER_CAMPAIGN_SATISFIES_WHITELISTING_OR_STORAGE,
                  file: FILE,
                  campaign_key: campaign["key"],
                  user_id: user_id,
                  group_name: group_name,
                  type: "whitelisting"
                ),
                disable_logs
              )
              return true
            end
          end
        end

        group_campaigns.each do |campaign|
          if called_campaign["id"] != campaign["id"]
            user_storage_data = get_user_storage(user_id, campaign["key"], true)
            if user_storage_data
              @logger.log(
                LogLevelEnum::INFO,
                format(
                  LogMessageEnum::InfoMessages::OTHER_CAMPAIGN_SATISFIES_WHITELISTING_OR_STORAGE,
                  file: FILE,
                  campaign_key: campaign["key"],
                  user_id: user_id,
                  group_name: group_name,
                  type: "user storage"
                ),
                disable_logs
              )
              return true
            end
          end
        end
        false
      end

      # Get variation if whitelisting passes
      #
      # @param[String]  :user_id                            the unique ID assigned to User
      # @param[Hash]    :campaign                           campaign for which checking whitelisting
      # @param[Hash]    :variation_targeting_variables      Key/value pair of Whitelisting Custom Attributes
      # @param[String]  :api_name                           The key Passed to identify the calling API
      # @param[Hash]    :decision                           data containing campaign info passed to hooks manager
      # @param[Boolean] :disable_logs                       optional: disable logs if True
      # @return[Hash]
      def get_variation_if_whitelisting_passed(user_id, campaign, variation_targeting_variables, api_name, decision, disable_logs = false)
        campaign_key = campaign['key']
        if campaign['isForcedVariationEnabled']
          variation = evaluate_whitelisting(
            user_id,
            campaign,
            api_name,
            campaign_key,
            variation_targeting_variables,
            disable_logs
          )
          status = if variation
                     StatusEnum::PASSED
                   else
                     StatusEnum::FAILED
                   end

          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::SEGMENTATION_STATUS,
              file: FILE,
              campaign_key: campaign_key,
              user_id: user_id,
              status: status,
              custom_variables: variation_targeting_variables ? variation_targeting_variables : {},
              variation_name: (status == StatusEnum::PASSED && campaign['type'] != CampaignTypes::FEATURE_ROLLOUT) ? "and #{variation['name']} is Assigned" : ' ',
              segmentation_type: SegmentationTypeEnum::WHITELISTING,
              api_name: api_name
            ),
            disable_logs
          )

          if variation
            if campaign['type'] == CampaignTypes::VISUAL_AB || campaign['type'] == CampaignTypes::FEATURE_TEST
              decision[:variation_name] = variation['name']
              decision[:variation_id] = variation['id']
              if campaign['type'] == CampaignTypes::FEATURE_TEST
                decision[:is_feature_enabled] = variation['isFeatureEnabled']
              end
            end
            decision[:is_user_whitelisted] = true
            @hooks_manager.execute(decision)
          end

          return variation if variation && variation['name']
        else
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::WHITELISTING_SKIPPED,
              file: FILE,
              campaign_key: campaign_key,
              user_id: user_id,
              api_name: api_name
            ),
            disable_logs
          )
        end
        nil
      end

    end
  end
end

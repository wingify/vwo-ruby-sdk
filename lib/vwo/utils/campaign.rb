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

require_relative '../logger'
require_relative '../enums'
require_relative '../constants'

# Utility module for processing VWO campaigns
class VWO
  module Utils
    module Campaign
      include VWO::Enums
      include VWO::CONSTANTS

      # Sets variation allocation range in the provided campaign
      #
      # @param [Hash]: Campaign object

      def set_variation_allocation(campaign)
        current_allocation = 0
        campaign['variations'].each do |variation|
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

          VWO::Logger.get_instance.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::VARIATION_RANGE_ALLOCATION,
              file: FileNameEnum::CampaignUtil,
              campaign_key: campaign['key'],
              variation_name: variation['name'],
              variation_weight: variation['weight'],
              start: variation['start_variation_allocation'],
              end: variation['end_variation_allocation']
            )
          )
        end
      end

      # Sets campaign allocation range in the provided campaigns list
      #
      # @param [Array]: Array of Campaigns
      def set_campaign_allocation(campaigns)
        current_allocation = 0
        campaigns.each do |campaign|
          step_factor = get_variation_bucketing_range(campaign['weight'])
          if step_factor > 0
            start_range = current_allocation + 1
            end_range = current_allocation + step_factor
            campaign['min_range'] = start_range
            campaign['max_range'] = end_range
            current_allocation += step_factor
          else
            campaign['min_range'] = -1
            campaign['max_range'] = -1
          end
        end
      end

      # Returns goal from given campaign_key and gaol_identifier.
      # @param[String]            :campaign             Campaign object
      # @param[String]            :goal_identifier      Goal identifier
      #
      # @return[Hash]                                  Goal corresponding to Goal_identifier in respective campaign

      def get_campaign_goal(campaign, goal_identifier)
        return unless campaign && goal_identifier

        campaign['goals'].find do |goal|
          goal['identifier'] == goal_identifier
        end
      end

      # Returns segments from the campaign
      # @param[Hash]          campaign      Running campaign
      # @return[Hash]         A dsl of segments
      #
      def get_segments(campaign)
        campaign['segments']
      end

      # Returns control variation from a given campaign
      # @param[Hash]          campaign      Running campaign
      # @return[Hash]         variation     Control variation from the campaign, ie having id = 1

      def get_control_variation(campaign)
        campaign['variations'].find do |variation|
          variation['id'] == 1
        end
      end

      # Returns variable from given variables list.
      # @params[Array]          variables           List of variables, whether in campaigns or inside variation
      # @param[String]          variable_key        Variable identifier
      # @return[Hash]                               Variable corresponding to variable_key in given variable list

      def get_variable(variables, variable_key)
        variables.find do |variable|
          variable['key'] == variable_key
        end
      end

      private

      # Returns the bucket size of variation.
      # @param (Number): weight of variation
      # @return (Integer): Bucket start range of Variation

      def get_variation_bucketing_range(weight)
        return 0 if weight.nil? || weight == 0

        start_range = (weight * 100).ceil.to_i
        [start_range, MAX_TRAFFIC_VALUE].min
      end

      # Returns variation from given campaign_key and variation_name.
      #
      # @param[Hash]            :settings_file  Settings file
      # @param[Hash]            :campaign_key Campaign identifier key
      # @param[String]          :variation_name Variation identifier
      #
      # @return[Hash]           Variation corresponding to variation_name in respective campaign

      def get_campaign_variation(settings_file, campaign_key, variation_name)
        return unless settings_file && campaign_key && variation_name

        campaign = get_campaign(settings_file, campaign_key)
        return unless campaign

        campaign['variations'].find do |variation|
          variation['name'] == variation_name
        end
      end

      # Finds and Returns campaign from given campaign_key.
      # [Hash]                :settings_file          Settings file for the project
      # [String]              :campaign_key           Campaign identifier key
      # @return[Hash]                                 Campaign object

      def get_campaign(settings_file, campaign_key)
        settings_file['campaigns'].find do |campaign|
          campaign['key'] == campaign_key
        end
      end

      #  fetch campaigns from settings
      #
      #  [string|array|nil] :campaign_key
      #  [Hash]             :settings_file
      #  [string]           :goal_identifier
      #  [string]           :goal_type_to_track
      #  @return[Hash]
      def get_campaigns(settings_file, campaign_key, goal_identifier, goal_type_to_track = 'ALL')
        campaigns = []
        if campaign_key.nil?
          campaigns = get_campaigns_for_goal(settings_file, goal_identifier, goal_type_to_track)
        elsif campaign_key.is_a?(Array)
          campaigns = get_campaigns_from_campaign_keys(campaign_key, settings_file, goal_identifier, goal_type_to_track)
        elsif campaign_key.is_a?(String)
          campaign = get_campaign_for_campaign_key_and_goal(campaign_key, settings_file, goal_identifier, goal_type_to_track)
          if campaign
            campaigns = [campaign]
          end
        end
        if campaigns.length() == 0
          VWO::Logger.get_instance.log(
            LogLevelEnum::ERROR,
            format(
              LogMessageEnum::ErrorMessages::NO_CAMPAIGN_FOUND,
              file: FileNameEnum::CampaignUtil,
              goal_identifier: goal_identifier
            )
          )
        end
        return campaigns
      end

      # fetch all running campaigns (having goal identifier goal_type_to_track and goal type CUSTOM|REVENUE|ALL) from settings
      #
      #  [Hash]             :settings_file
      #  [string]           :goal_identifier
      #  [string]           :goal_type_to_track
      #  @return[Hash]
      def get_campaigns_for_goal(settings_file, goal_identifier, goal_type_to_track = 'ALL')
        campaigns = []
        if settings_file
          settings_file['campaigns'].each do |campaign|
            if campaign.key?(:status) && campaign[:status] != 'RUNNING'
              next
            end
            goal = get_campaign_goal(campaign, goal_identifier)
            if validate_goal(goal, goal_type_to_track)
              campaigns.push(campaign)
            end
          end
        end
        campaigns
      end

      def validate_goal(goal, goal_type_to_track)
        result = goal && (
          goal_type_to_track == 'ALL' ||
            (
              GOAL_TYPES.has_value?(goal['type']) &&
                (GOAL_TYPES.key? goal_type_to_track) &&
                goal['type'] == GOAL_TYPES[goal_type_to_track]
            )
        )
        return result
      end

      def get_campaigns_from_campaign_keys(campaign_keys, settings_file, goal_identifier, goal_type_to_track = 'ALL')
        campaigns = []
        campaign_keys.each do |campaign_key|

          campaign = get_campaign_for_campaign_key_and_goal(campaign_key, settings_file, goal_identifier, goal_type_to_track)
          if campaign
            campaigns.push(campaign)
          end
        end
        campaigns
      end

      def get_campaign_for_campaign_key_and_goal(campaign_key, settings_file, goal_identifier, goal_type_to_track)
        campaign = get_running_campaign(campaign_key, settings_file)
        if campaign
          goal = get_campaign_goal(campaign, goal_identifier)
          if validate_goal(goal, goal_type_to_track)
            return campaign
          end
        end
        nil
      end

      def get_running_campaign(campaign_key, settings_file)
        campaign = get_campaign(settings_file, campaign_key)
        if campaign.nil? || (campaign['status'] != 'RUNNING')
          @logger.log(
            LogLevelEnum::ERROR,
            format(
              LogMessageEnum::ErrorMessages::CAMPAIGN_NOT_RUNNING,
              file: FILE,
              campaign_key: campaign_key,
              api_name: ApiMethods::TRACK
            )
          )
          nil
        end
        return campaign
      end

      # Checks whether a campaign is part of a group.
      #
      #  @param[Hash]       :settings_file          Settings file for the project
      #  @param[Integer]     :campaign_id            Id of campaign which is to be checked
      #  @return[Boolean]
      def is_part_of_group(settings_file, campaign_id)
        if settings_file["campaignGroups"] && (settings_file["campaignGroups"].has_key?(campaign_id.to_s))
          return true
        end
        false
      end

      # Returns campaigns which are part of given group using group_id.
      #
      #  @param[Hash]       :settings_file          Settings file for the project
      #  @param[Integer]    :group_id               id of group whose campaigns are to be return
      #  @return[Array]
      def get_group_campaigns(settings_file, group_id)
        group_campaign_ids = []
        group_campaigns = []
        groups = settings_file["groups"]

        if groups && groups.has_key?(group_id.to_s)
          group_campaign_ids = groups[group_id.to_s]["campaigns"]
        end

        if group_campaign_ids
          group_campaign_ids.each do |campaign_id|
            settings_file["campaigns"].each do |campaign|
              if campaign["id"] == campaign_id && campaign["status"] == STATUS_RUNNING
                group_campaigns.push(campaign)
              end
            end
          end
        end
        group_campaigns
      end

    end
  end
end

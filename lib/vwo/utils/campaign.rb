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
    end
  end
end

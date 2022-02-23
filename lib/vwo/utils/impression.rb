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
require 'cgi'
require_relative '../logger'
require_relative '../enums'
require_relative '../constants'
require_relative 'function'
require_relative 'uuid'
require_relative 'utility'

# Creates the impression from the arguments passed
class VWO
  module Utils
    module Impression
      include VWO::Enums
      include VWO::CONSTANTS
      include VWO::Utils::Function
      include UUID
      include VWO::Utils::Utility

      # Creates the impression from the arguments passed
      #
      # @param[Hash]                        :settings_file          Settings file object
      # @param[String]                      :campaign_id            Campaign identifier
      # @param[String]                      :variation_id           Variation identifier
      # @param[String]                      :user_id                User identifier
      # @param[String]                      :sdk_key                SDK Key
      # @param[String]                      :goal_id                Goal identifier, if building track impression
      # @param[String|Float|Integer|nil)    :revenue                Number value, in any representation, if building track impression
      #
      # @return[nil|Hash]                                           None if campaign ID or variation ID is invalid,
      #                                                             Else Properties(dict)
      def create_impression(settings_file, campaign_id, variation_id, user_id, sdk_key, goal_id = nil, revenue = nil, usage_stats = {})
        return unless valid_number?(campaign_id) && valid_string?(user_id)

        is_track_user_api = true
        is_track_user_api = false unless goal_id.nil?
        account_id = settings_file['accountId']

        impression = {
          account_id: account_id,
          experiment_id: campaign_id,
          ap: PLATFORM,
          combination: variation_id,
          random: get_random_number,
          sId: get_current_unix_timestamp,
          u: generator_for(user_id, account_id),
          env: sdk_key
        }
        # Version and SDK constants
        sdk_version = Gem.loaded_specs['vwo_sdk'] ? Gem.loaded_specs['vwo_sdk'].version : VWO::SDK_VERSION
        impression['sdk'] = 'ruby'
        impression['sdk-v'] = sdk_version

        impression = usage_stats.merge(impression)

        logger = VWO::Logger.get_instance

        if is_track_user_api
          impression['ed'] = JSON.generate(p: 'server')
          impression['url'] = HTTPS_PROTOCOL + get_url(ENDPOINTS::TRACK_USER)
          logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::IMPRESSION_FOR_TRACK_USER,
              file: FileNameEnum::ImpressionUtil,
              properties: remove_sensitive_properties(impression)
            )
          )
        else
          impression['url'] = HTTPS_PROTOCOL + get_url(ENDPOINTS::TRACK_GOAL)
          impression['goal_id'] = goal_id
          impression['r'] = revenue if revenue
          logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::IMPRESSION_FOR_TRACK_GOAL,
              file: FileNameEnum::ImpressionUtil,
              properties: remove_sensitive_properties(impression)
            )
          )
        end
        impression
      end

      # Returns commonly used params for making requests to our servers.
      #
      # @param[String]                :user_id                Unique identification of user
      # @param[String]                :settings_file          Settings file containing campaign data for extracting account_id
      # @return[Hash]                                         Commonly used params for making call to our servers
      #
      def get_common_properties(user_id, settings_file)
        account_id = settings_file['accountId']
        {
          'random' => get_random_number,
          'sdk' => SDK_NAME,
          'sdk-v' => SDK_VERSION,
          'ap' => PLATFORM,
          'sId' => get_current_unix_timestamp,
          'u' => generator_for(user_id, account_id),
          'account_id' => account_id
        }
      end

      # Creates properties for the bulk impression event
      #
      # @param[Hash]                        :settings_file          Settings file object
      # @param[String]                      :campaign_id            Campaign identifier
      # @param[String]                      :variation_id           Variation identifier
      # @param[String]                      :user_id                User identifier
      # @param[String]                      :sdk_key                SDK Key
      # @param[String]                      :goal_id                Goal identifier, if building track impression
      # @param[String|Float|Integer|nil)    :revenue                Number value, in any representation, if building track impression
      #
      # @return[nil|Hash]                                           None if campaign ID or variation ID is invalid,
      #                                                             Else Properties(dict)
      def create_bulk_event_impression(settings_file, campaign_id, variation_id, user_id, goal_id = nil, revenue = nil)
        return unless valid_number?(campaign_id) && valid_string?(user_id)
        is_track_user_api = true
        is_track_user_api = false unless goal_id.nil?
        account_id = settings_file['accountId']
        impression = {
          eT: is_track_user_api ? 1 : 2,
          e: campaign_id,
          c: variation_id,
          u: generator_for(user_id, account_id),
          sId: get_current_unix_timestamp
        }
        logger = VWO::Logger.get_instance
        if is_track_user_api
          logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::IMPRESSION_FOR_TRACK_USER,
              file: FileNameEnum::ImpressionUtil,
              properties: JSON.generate(impression)
            )
          )
        else
          impression['g'] = goal_id
          impression['r'] = revenue if revenue
          logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::IMPRESSION_FOR_TRACK_GOAL,
              file: FileNameEnum::ImpressionUtil,
              properties: JSON.generate(impression)
            )
          )
        end
        impression
      end

      # Builds generic properties for different tracking calls required by VWO servers.
      #
      # @param[Hash]                      :settings_file
      # @param[String]                    :sdk_key
      # @param[String]                    :event_name
      # @param[Hash]                      :usage_stats
      # @return[Hash]                     :properties
      # 
      def get_events_base_properties(settings_file, event_name, usage_stats = {})
        properties = {
          en: event_name,
          a: settings_file['accountId'],
          env: settings_file['sdkKey'],
          eTime: get_current_unix_timestamp_in_millis,
          random: get_random_number,
          p: "FS"
        }

        if event_name == EventEnum::VWO_VARIATION_SHOWN
          properties = properties.merge(usage_stats)
        end
        properties
      end

      # Builds generic payload required by all the different tracking calls.
      #
      # @param[Hash]                   :settings_file
      # @param[String]                 :user_id
      # @param[String]                 :event_name
      # @param[Hash]                   :usage_stats
      # @return[Hash]                  :properties
      # 
      def get_event_base_payload(settings_file, user_id, event_name, usage_stats = {})
        uuid = generator_for(user_id, (settings_file['accountId']))
        sdk_key = settings_file['sdkKey']

        props = {
          sdkName: SDK_NAME,
          sdkVersion: SDK_VERSION,
          '$visitor': {
            props: {
              vwo_fs_environment: sdk_key
            }
          }
        }

        # if usage_stats
        #   props = props.merge(usage_stats)
        # end

        properties = {
          d: {
            msgId: uuid + '_' + Time.now.to_i.to_s,
            visId: uuid,
            sessionId: Time.now.to_i,
            event: {
              props: props,
              name: event_name,
              time: get_current_unix_timestamp_in_millis
            },
            visitor: {
              props: {
                vwo_fs_environment: sdk_key
              }
            }
          }
        }

        properties
      end

      # Builds payload to track the visitor.
      #
      # @param[Hash]                   :settings_file
      # @param[String]                 :user_id
      # @param[String]                 :event_name
      # @param[Integer]                :campaign_id
      # @param[Integer]                :variation_id
      # @param[Hash]                   :usage_stats
      # @return[Hash]                  :properties
      #
      def get_track_user_payload_data(settings_file, user_id, event_name, campaign_id, variation_id, usage_stats = {})
        properties = get_event_base_payload(settings_file, user_id, event_name)
        properties[:d][:event][:props][:id] = campaign_id
        properties[:d][:event][:props][:variation] = variation_id

        #this is currently required by data-layer team, we can make changes on DACDN and remove it from here
        properties[:d][:event][:props][:isFirst] = 1

        logger = VWO::Logger.get_instance
        logger.log(
            LogLevelEnum::DEBUG,
          format(
            LogMessageEnum::DebugMessages::IMPRESSION_FOR_EVENT_ARCH_TRACK_USER,
            file: FileNameEnum::ImpressionUtil,
            a: settings_file['accountId'],
            u: user_id,
            c: campaign_id.to_s
          )
        )
        properties
      end

      # Builds payload to track the Goal.
      #
      # @param[Hash]                   :settings_file
      # @param[String]                 :user_id
      # @param[String]                 :event_name
      # @param[Integer]                :revenue_value
      # @param[Hash]                   :metric_map
      # @param[Array]                  :revenue_props
      #
      # @return[Hash]                  :properties
      #
      def get_track_goal_payload_data(settings_file, user_id, event_name, revenue_value, metric_map, revenue_props = [])
        properties = get_event_base_payload(settings_file, user_id, event_name)

        logger = VWO::Logger.get_instance
        metric = {}
        metric_map.each do |campaign_id, goal_id|
          metric[('id_' + campaign_id.to_s).to_sym] = ['g_' + goal_id.to_s]
          logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::IMPRESSION_FOR_EVENT_ARCH_TRACK_GOAL,
              file: FileNameEnum::ImpressionUtil,
              goal_identifier: event_name,
              a: settings_file['accountId'],
              u: user_id,
              c: campaign_id
            )
          )
        end

        properties[:d][:event][:props][:vwoMeta] = {
          metric: metric
        }

        if revenue_props.length() != 0 && revenue_value
          revenue_props.each do |revenue_prop|
            properties[:d][:event][:props][:vwoMeta][revenue_prop.to_sym] = revenue_value
          end
        end

        properties[:d][:event][:props][:isCustomEvent] = true
        properties
      end

      # Builds payload to appply post segmentation on VWO campaign reports.
      #
      # @param[Hash]                   :settings_file
      # @param[String]                 :user_id
      # @param[String]                 :event_name
      # @param[Hash]                   :custom_dimension_map
      #
      # @return[Hash]                  :properties
      #
      def get_push_payload_data(settings_file, user_id, event_name, custom_dimension_map = {})
        properties = get_event_base_payload(settings_file, user_id, event_name)
        properties[:d][:event][:props][:isCustomEvent] = true

        custom_dimension_map.each do |tag_key, tag_value|
          properties[:d][:event][:props][('$visitor'.to_sym)][:props][tag_key] = tag_value
          properties[:d][:visitor][:props][tag_key] = tag_value
        end

        logger = VWO::Logger.get_instance
        logger.log(
          LogLevelEnum::DEBUG,
          format(
            LogMessageEnum::DebugMessages::IMPRESSION_FOR_EVENT_ARCH_PUSH,
            file: FileNameEnum::ImpressionUtil,
            a: settings_file['accountId'],
            u: user_id,
            property: JSON.generate(custom_dimension_map)
          )
        )
        properties
      end
    end
  end
end

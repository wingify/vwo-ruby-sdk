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
require_relative '../enums'
require_relative '../constants'
require_relative './log_message'
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
          u: generator_for(user_id, account_id, true),
          env: sdk_key
        }
        # Version and SDK constants
        sdk_version = Gem.loaded_specs['vwo_sdk'] ? Gem.loaded_specs['vwo_sdk'].version : VWO::SDK_VERSION
        impression['sdk'] = 'ruby'
        impression['sdk-v'] = sdk_version

        impression = usage_stats.merge(impression)

        if is_track_user_api
          impression['ed'] = JSON.generate(p: 'server')
          impression['url'] = HTTPS_PROTOCOL + get_url(ENDPOINTS::TRACK_USER)
          Logger.log(
            LogLevelEnum::DEBUG,
            'IMPRESSION_FOR_TRACK_USER',
            {
              '{file}' => FileNameEnum::IMPRESSION_UTIL,
              '{properties}' => remove_sensitive_properties(impression)
            }
          )
        else
          impression['url'] = HTTPS_PROTOCOL + get_url(ENDPOINTS::TRACK_GOAL)
          impression['goal_id'] = goal_id
          impression['r'] = revenue if revenue
          Logger.log(
            LogLevelEnum::DEBUG,
            'IMPRESSION_FOR_TRACK_GOAL',
            {
              '{file}' => FileNameEnum::IMPRESSION_UTIL,
              '{properties}' => JSON.generate(impression)
            }
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
          'u' => generator_for(user_id, account_id, true),
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
      def create_bulk_event_impression(settings_file, campaign_id, variation_id, user_id, goal_id = nil, revenue = nil, event_properties = {} ,options = {})
        return unless valid_number?(campaign_id) && valid_string?(user_id)

        is_track_user_api = true
        is_track_user_api = false unless goal_id.nil?
        account_id = settings_file['accountId']
        impression = {
          eT: is_track_user_api ? 1 : 2,
          e: campaign_id,
          c: variation_id,
          u: generator_for(user_id, account_id, true),
          sId: get_current_unix_timestamp
        }

        # Check if user_agent is provided
        if options[:user_agent]
          impression['visitor_ua'] = options[:user_agent]
        end
        # Check if user_ip_address is provided
        if options[:user_ip_address]
          impression['visitor_ip'] = options[:user_ip_address]
        end

        if is_track_user_api
          Logger.log(
            LogLevelEnum::DEBUG,
            'IMPRESSION_FOR_TRACK_USER',
            {
              '{file}' => FileNameEnum::IMPRESSION_UTIL,
              '{properties}' => remove_sensitive_properties(impression)
            }
          )
        else
          impression['g'] = goal_id
          impression['r'] = revenue if revenue

          if settings_file.key?('isEventArchEnabled') && settings_file['isEventArchEnabled']
            impression['eventProps'] = event_properties
          end

          Logger.log(
            LogLevelEnum::DEBUG,
            'IMPRESSION_FOR_TRACK_GOAL',
            {
              '{file}' => FileNameEnum::IMPRESSION_UTIL,
              '{properties}' => JSON.generate(impression)
            }
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
          p: 'FS'
        }

        properties = properties.merge(usage_stats) if event_name == EventEnum::VWO_VARIATION_SHOWN
        properties
      end

      # Builds generic payload required by all the different tracking calls.
      #
      # @param[Hash]                   :settings_file
      # @param[String]                 :user_id
      # @param[String]                 :event_name
      # @param[Hash]                   :_usage_stats
      # @return[Hash]                  :properties
      #
      def get_event_base_payload(settings_file, user_id, event_name, _usage_stats = {})
        uuid = generator_for(user_id, (settings_file['accountId']), true)
        sdk_key = settings_file['sdkKey']

        props = {
          vwo_sdkName: SDK_NAME,
          vwo_sdkVersion: SDK_VERSION,

        }

        # if usage_stats
        #   props = props.merge(_usage_stats)
        # end

        {
          d: {
            msgId: "#{uuid}-#{get_current_unix_timestamp_in_millis}",
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
      end

      # Builds payload to track the visitor.
      #
      # @param[Hash]                   :settings_file
      # @param[String]                 :user_id
      # @param[String]                 :event_name
      # @param[Integer]                :campaign_id
      # @param[Integer]                :variation_id
      # @param[Hash]                   :_usage_stats
      # @return[Hash]                  :properties
      #
      def get_track_user_payload_data(settings_file, user_id, event_name, campaign_id, variation_id, _usage_stats = {})
        properties = get_event_base_payload(settings_file, user_id, event_name)
        properties[:d][:event][:props][:id] = campaign_id
        properties[:d][:event][:props][:variation] = variation_id

        # this is currently required by data-layer team, we can make changes on DACDN and remove it from here
        properties[:d][:event][:props][:isFirst] = 1

        Logger.log(
          LogLevelEnum::DEBUG,
          'IMPRESSION_FOR_EVENT_ARCH_TRACK_USER',
          {
            '{file}' => FileNameEnum::IMPRESSION_UTIL,
            '{accountId}' => settings_file['accountId'],
            '{userId}' => user_id,
            '{campaignId}' => campaign_id.to_s
          }
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
      # @param[Hash] :properties associated with the event.
      #
      # @return[Hash]                  :properties
      #
      def get_track_goal_payload_data(settings_file, user_id, event_name, revenue_value, metric_map, revenue_props = [], event_properties)
        properties = get_event_base_payload(settings_file, user_id, event_name)

        metric = {}
        metric_map.each do |campaign_id, goal_id|
          metric["id_#{campaign_id}".to_sym] = ["g_#{goal_id}"]
          Logger.log(
            LogLevelEnum::DEBUG,
            'IMPRESSION_FOR_EVENT_ARCH_TRACK_GOAL',
            {
              '{file}' => FileNameEnum::IMPRESSION_UTIL,
              '{accountId}' => settings_file['accountId'],
              '{goalName}' => event_name,
              '{userId}' => user_id,
              '{campaignId}' => campaign_id.to_s
            }
          )
        end

        properties[:d][:event][:props][:vwoMeta] = {
          metric: metric
        }

        if revenue_props.length != 0 && revenue_value
          revenue_props.each do |revenue_prop|
            properties[:d][:event][:props][:vwoMeta][revenue_prop.to_sym] = revenue_value
          end
        end

        properties[:d][:event][:props][:isCustomEvent] = true

        if event_properties && event_properties.any?
          event_properties.each do |prop, value|
            properties[:d][:event][:props][prop] = value
          end
        end

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
          properties[:d][:event][:props][tag_key] = tag_value
          properties[:d][:visitor][:props][tag_key] = tag_value
        end

        Logger.log(
          LogLevelEnum::DEBUG,
          'IMPRESSION_FOR_EVENT_ARCH_PUSH',
          {
            '{file}' => FileNameEnum::IMPRESSION_UTIL,
            '{accountId}' => settings_file['accountId'],
            '{userId}' => user_id,
            '{property}' => JSON.generate(custom_dimension_map)
          }
        )
        properties
      end

      def get_batch_event_query_params(account_id, sdk_key, usage_stats = {})
        {
          a: account_id,
          sd: SDK_NAME,
          sv: SDK_VERSION,
          env: sdk_key
        }.merge(usage_stats)
      end
    end
  end
end

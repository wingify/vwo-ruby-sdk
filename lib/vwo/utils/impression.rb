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

require 'json'
require 'cgi'
require_relative '../logger'
require_relative '../enums'
require_relative '../constants'
require_relative 'function'
require_relative 'uuid'

# Creates the impression from the arguments passed
class VWO
  module Utils
    module Impression
      include VWO::Enums
      include VWO::CONSTANTS
      include VWO::Utils::Function
      include UUID

      # Creates the impression from the arguments passed
      #
      # @param[Hash]                        :settings_file           Settings file object
      # @param[String]                      :campaign_id            Campaign identifier
      # @param[String]                      :variation_id           Variation identifier
      # @param[String]                      :user_id                User identifier
      # @param[String]                      :goal_id                Goal identifier, if building track impression
      # @param[String|Float|Integer|nil)    :revenue                Number value, in any representation, if building track impression
      #
      # @return[nil|Hash]                                           None if campaign ID or variation ID is invalid,
      #                                                             Else Properties(dict)
      def create_impression(settings_file, campaign_id, variation_id, user_id, goal_id = nil, revenue = nil)
        return unless valid_number?(campaign_id) && valid_string?(user_id)

        is_track_user_api = true
        is_track_user_api = false unless goal_id.nil?
        account_id = settings_file['accountId']

        impression = {
          account_id: account_id,
          experiment_id: campaign_id,
          ap: PLATFORM,
          uId: CGI.escape(user_id.encode('utf-8')),
          combination: variation_id,
          random: get_random_number,
          sId: get_current_unix_timestamp,
          u: generator_for(user_id, account_id)
        }
        # Version and SDK constants
        sdk_version = Gem.loaded_specs['vwo_sdk'] ? Gem.loaded_specs['vwo_sdk'].version : VWO::SDK_VERSION
        impression['sdk'] = 'ruby'
        impression['sdk-v'] = sdk_version

        url = HTTPS_PROTOCOL + ENDPOINTS::BASE_URL
        logger = VWO::Logger.get_instance

        if is_track_user_api
          impression['ed'] = JSON.generate(p: 'server')
          impression['url'] = "#{url}#{ENDPOINTS::TRACK_USER}"
          logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::IMPRESSION_FOR_TRACK_USER,
              file: FileNameEnum::ImpressionUtil,
              properties: JSON.generate(impression)
            )
          )
        else
          impression['url'] = url + ENDPOINTS::TRACK_GOAL
          impression['goal_id'] = goal_id
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
    end
  end
end

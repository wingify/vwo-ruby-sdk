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

require_relative '../enums'
require_relative '../utils/request'
require_relative '../utils/utility'
require_relative '../utils/log_message'
require_relative '../constants'

class VWO
  module Services
    class EventDispatcher
      include VWO::Enums
      include VWO::CONSTANTS
      include Utils::Utility

      EXCLUDE_KEYS = ['url'].freeze

      # Initialize the dispatcher with logger and development mode
      #
      # @param [Boolean] :  To specify whether the request
      #                     to our server should be made or not.
      #
      def initialize(is_development_mode = false)
        @logger = VWO::Utils::Logger
        @is_development_mode = is_development_mode
      end

      # Dispatch the impression event having properties object only if dev-mode is OFF
      #
      # @param[Hash]        :properties       hash having impression properties
      #                                       the request to be dispatched to the VWO server
      # @return[Boolean]
      #
      def dispatch(impression, main_keys, end_point)
        return true if @is_development_mode

        modified_event = impression.reject do |key, _value|
          EXCLUDE_KEYS.include?(key)
        end

        resp = VWO::Utils::Request.get(impression['url'], modified_event)
        if resp.code == '200'
          @logger.log(
            LogLevelEnum::INFO,
            'IMPRESSION_SUCCESS',
            {
              '{file}' => FILE,
              '{endPoint}' => end_point,
              '{accountId}' => impression['account_id'] || impression[:account_id],
              '{mainKeys}' => JSON.generate(main_keys)
            }
          )
          true
        else
          @logger.log(
            LogLevelEnum::ERROR,
            'IMPRESSION_FAILED',
            {
              '{file}' => FileNameEnum::BATCH_EVENTS_DISPATCHER,
              '{err}' => resp.message,
              '{endPoint}' => impression['url']
            }
          )
          false
        end
      rescue StandardError => e
        @logger.log(
          LogLevelEnum::ERROR,
          'IMPRESSION_FAILED',
          {
            '{file}' => FileNameEnum::BATCH_EVENTS_DISPATCHER,
            '{err}' => e.message,
            '{endPoint}' => impression['url']
          }
        )
        false
      end

      def dispatch_event_arch_post(params, post_data, options = {})
        return true if @is_development_mode

        url = HTTPS_PROTOCOL + get_url(ENDPOINTS::EVENTS)
        resp = VWO::Utils::Request.event_post(url, params, post_data, SDK_NAME, options)
        if resp.code == '200'
          @logger.log(
            LogLevelEnum::INFO,
            'IMPRESSION_SUCCESS_FOR_EVENT_ARCH',
            {
              '{file}' => FileNameEnum::BATCH_EVENTS_DISPATCHER,
              '{event}' => "visitor property:#{JSON.generate(post_data[:d][:visitor][:props])}",
              '{endPoint}' => url,
              '{accountId}' => params[:a]
            }
          )
          true
        else
          @logger.log(
            LogLevelEnum::ERROR,
            'IMPRESSION_FAILED',
            {
              '{file}' => FileNameEnum::EVENT_DISPATCHER,
              '{err}' => resp.message,
              '{endPoint}' => url
            }
          )
          false
        end
      rescue StandardError => e
        @logger.log(
          LogLevelEnum::ERROR,
          'IMPRESSION_FAILED',
          {
            '{file}' => FileNameEnum::EVENT_DISPATCHER,
            '{err}' => e.message,
            '{endPoint}' => url
          }
        )
        false
      end
    end
  end
end

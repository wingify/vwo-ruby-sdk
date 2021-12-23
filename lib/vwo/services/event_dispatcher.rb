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
require_relative '../utils/request'
require_relative '../constants'

class VWO
  module Services
    class EventDispatcher
      include VWO::Enums
      include VWO::CONSTANTS

      EXCLUDE_KEYS = ['url'].freeze

      # Initialize the dispatcher with logger and development mode
      #
      # @param [Boolean] :  To specify whether the request
      #                     to our server should be made or not.
      #
      def initialize(is_development_mode = false)
        @logger = VWO::Logger.get_instance
        @is_development_mode = is_development_mode
      end

      # Dispatch the impression event having properties object only if dev-mode is OFF
      #
      # @param[Hash]        :properties       hash having impression properties
      #                                       the request to be dispatched to the VWO server
      # @return[Boolean]
      #
      def dispatch(impression)
        return true if @is_development_mode

        modified_event = impression.reject do |key, _value|
          EXCLUDE_KEYS.include?(key)
        end

        resp = VWO::Utils::Request.get(impression['url'], modified_event)
        if resp.code == '200'
          true
        else
          @logger.log(
            LogLevelEnum::ERROR,
            format(LogMessageEnum::ErrorMessages::IMPRESSION_FAILED, file: FileNameEnum::EventDispatcher, end_point: impression['url'])
          )
          false
        end
      rescue StandardError
        @logger.log(
          LogLevelEnum::ERROR,
          format(LogMessageEnum::ErrorMessages::IMPRESSION_FAILED, file: FileNameEnum::EventDispatcher, end_point: impression['url'])
        )
        false
      end

      def dispatch_event_arch_post(params, post_data)
        return true if @is_development_mode

        url = HTTPS_PROTOCOL + ENDPOINTS::BASE_URL + ENDPOINTS::EVENTS
        resp = VWO::Utils::Request.event_post(url, params, post_data, SDK_NAME)
        if resp.code == '200'
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::IMPRESSION_SUCCESS_FOR_EVENT_ARCH, 
              file: FileNameEnum::EventDispatcher, 
              event: 'visitor property:' + JSON.generate(post_data[:d][:visitor][:props]), 
              url: url,
              a: params[:a]
            )
          )
          true
        else
          @logger.log(
            LogLevelEnum::ERROR,
            format(LogMessageEnum::ErrorMessages::IMPRESSION_FAILED, file: FileNameEnum::EventDispatcher, end_point: url)
          )
          false
        end
      rescue StandardError
        @logger.log(
          LogLevelEnum::ERROR,
          format(LogMessageEnum::ErrorMessages::IMPRESSION_FAILED, file: FileNameEnum::EventDispatcher, end_point: url)
        )
        false
      end
    end
  end
end

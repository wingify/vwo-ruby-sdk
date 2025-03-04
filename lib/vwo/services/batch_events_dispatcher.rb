# Copyright 2019-2025 Wingify Software Pvt. Ltd.
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
class VWO
  module Services
    class BatchEventsDispatcher
      include VWO::Enums
      include VWO::Utils::Utility
      # Initialize the BatchEventDispatcher with logger and development mode
      #
      # @param [Boolean] :  To specify whether the request
      #                     to our server should be made or not.
      #
      def initialize(development_mode = false)
        @logger = VWO::Utils::Logger
        @development_mode = development_mode
        @queue = []
      end

      # Dispatch the impression event having properties object only if dev-mode is OFF
      #
      # @param[Hash]        :properties       hash having impression properties
      #                                       the request to be dispatched to the VWO server
      # @return[Boolean]
      #
      def dispatch(impression, callback, query_params)
        url = CONSTANTS::HTTPS_PROTOCOL + get_url(CONSTANTS::ENDPOINTS::BATCH_EVENTS)
        account_id = query_params[:a]
        resp = VWO::Utils::Request.post(url, query_params, impression)
        case resp.code
        when '200'
          @logger.log(
            LogLevelEnum::INFO,
            'IMPRESSION_BATCH_SUCCESS',
            {
              '{file}' => FILE,
              '{endPoint}' => url,
              '{accountId}' => account_id
            }
          )
          message = nil
        when '413'
          @logger.log(
            LogLevelEnum::DEBUG,
            'CONFIG_BATCH_EVENT_LIMIT_EXCEEDED',
            {
              '{file}' => FileNameEnum::BATCH_EVENTS_DISPATCHER,
              '{endPoint}' => url,
              '{eventsPerRequest}' => impression.length,
              '{accountId}' => impression[:a]
            }
          )

          @logger.log(
            LogLevelEnum::ERROR,
            'IMPRESSION_FAILED',
            {
              '{file}' => FileNameEnum::BATCH_EVENTS_DISPATCHER,
              '{err}' => resp.message,
              '{endPoint}' => url
            }
          )
          message = resp.message
        else
          @logger.log(
            LogLevelEnum::INFO,
            'IMPRESSION_BATCH_FAILED',
            { '{file}' => FileNameEnum::BATCH_EVENTS_DISPATCHER }
          )

          @logger.log(
            LogLevelEnum::ERROR,
            'IMPRESSION_FAILED',
            {
              '{file}' => FileNameEnum::BATCH_EVENTS_DISPATCHER,
              '{err}' => resp.message,
              '{endPoint}' => url
            }
          )
          message = resp.message
        end
        callback&.call(message, impression)
        true
      rescue StandardError => e
        @logger.log(
          LogLevelEnum::DEBUG,
          'IMPRESSION_BATCH_FAILED',
          { '{file}' => FileNameEnum::BATCH_EVENTS_DISPATCHER }
        )

        @logger.log(
          LogLevelEnum::ERROR,
          'IMPRESSION_FAILED',
          {
            '{file}' => FileNameEnum::BATCH_EVENTS_DISPATCHER,
            '{err}' => e.message,
            '{endPoint}' => url
          }
        )
        false
      end
    end
  end
end

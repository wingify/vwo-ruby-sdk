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
class VWO
  module Services
    class BatchEventsDispatcher
      include VWO::Enums
      # Initialize the BatchEventDispatcher with logger and development mode
      #
      # @param [Boolean] :  To specify whether the request
      #                     to our server should be made or not.
      #
      def initialize
        @logger = VWO::Logger.get_instance
        @queue = []
      end

      # Dispatch the impression event having properties object only if dev-mode is OFF
      #
      # @param[Hash]        :properties       hash having impression properties
      #                                       the request to be dispatched to the VWO server
      # @return[Boolean]
      #
      def dispatch(impression, callback, query_params)
        url = CONSTANTS::HTTPS_PROTOCOL + CONSTANTS::ENDPOINTS::BASE_URL + CONSTANTS::ENDPOINTS::BATCH_EVENTS
        account_id = query_params[:a]
        resp = VWO::Utils::Request.post(url, query_params, impression)
        if resp.code == '200'
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::BULK_IMPRESSION_SUCCESS,
              file: FileNameEnum::BatchEventsDispatcher,
              end_point: url,
              a: account_id
            )
          )
          message = nil
        elsif resp.code == '413'
          @logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::BATCH_EVENT_LIMIT_EXCEEDED,
              file: FileNameEnum::BatchEventsDispatcher,
              end_point: url,
              accountId: impression[:a],
              eventsPerRequest: impression.length()
            )
          )

          @logger.log(
            LogLevelEnum::ERROR,
            format(
              LogMessageEnum::ErrorMessages::IMPRESSION_FAILED,
              file: FileNameEnum::BatchEventsDispatcher,
              end_point: url
            )
          )
          message = resp.message
        else
          @logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::BULK_NOT_PROCESSED,
              file: FileNameEnum::BatchEventsDispatcher
              )
          )

          @logger.log(
            LogLevelEnum::ERROR,
            format(LogMessageEnum::ErrorMessages::IMPRESSION_FAILED, file: FileNameEnum::BatchEventsDispatcher, end_point: url)
          )
          message = resp.message
        end
        if callback
          callback.call(message, impression)
        end
      rescue StandardError => e
        @logger.log(
          LogLevelEnum::DEBUG,
          format(
            LogMessageEnum::DebugMessages::BULK_NOT_PROCESSED,
            file: FileNameEnum::BatchEventsDispatcher
          )
        )

        @logger.log(
          LogLevelEnum::ERROR,
          format(LogMessageEnum::ErrorMessages::IMPRESSION_FAILED, file: FileNameEnum::BatchEventsDispatcher, end_point: url)
        )
        false
      end

    end
  end
end

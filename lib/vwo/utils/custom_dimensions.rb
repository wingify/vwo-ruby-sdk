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

require 'json'
require_relative '../enums'
require_relative '../constants'
require_relative './impression'
require_relative './utility'
require_relative './log_message'

# Utility module for helper math and random functions
class VWO
  module Utils
    module CustomDimensions
      include VWO::CONSTANTS
      include VWO::Enums
      include VWO::Utils::Impression
      include VWO::Utils::Utility

      def get_url_params(settings_file, tag_key, tag_value, user_id, sdk_key)
        url = HTTPS_PROTOCOL + get_url(ENDPOINTS::PUSH)
        tag = { 'u' => {} }
        tag['u'][tag_key] = tag_value

        params = get_common_properties(user_id, settings_file)
        params.merge!('url' => url, 'tags' => JSON.generate(tag), 'env' => sdk_key)

        Logger.log(
          LogLevelEnum::DEBUG,
          'IMPRESSION_FOR_PUSH',
          {
            '{file}' => FileNameEnum::CUSTOM_DIMENSTIONS_UTIL,
            '{properties}' => JSON.generate(params)
          }
        )
        params
      end

      def get_batch_event_url_params(settings_file, tag_key, tag_value, user_id)
        tag = { 'u' => {} }
        tag['u'][tag_key] = tag_value

        account_id = settings_file['accountId']
        params = {
          'eT' => 3,
          't' => JSON.generate(tag),
          'u' => generator_for(user_id, account_id, true),
          'sId' => get_current_unix_timestamp
        }

        Logger.log(
          LogLevelEnum::DEBUG,
          'IMPRESSION_FOR_PUSH',
          {
            '{file}' => FileNameEnum::CUSTOM_DIMENSTIONS_UTIL,
            '{properties}' => JSON.generate(params)
          }
        )
        params
      end
    end
  end
end

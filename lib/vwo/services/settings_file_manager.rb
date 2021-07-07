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

require_relative '../utils/function'
require_relative '../utils/request'
require_relative '../utils/validations'
require_relative '../constants'

class VWO
  module Services
    class SettingsFileManager
      include ::VWO::Utils::Validations
      include ::VWO::Utils::Function

      PROTOCOL = 'https'
      HOSTNAME = ::VWO::CONSTANTS::ENDPOINTS::BASE_URL

      def initialize(account_id, sdk_key)
        @account_id = account_id
        @sdk_key = sdk_key
      end

      # Get Settings file method to retrieve settings_file for customer from VWO server
      # @param [string]:      Account ID of user
      # @param [string]:      Unique sdk key for user,
      #                       can be retrieved from VWO app
      # @return[string]:      JSON - settings_file,
      #                       as received from the server,
      #                       nil if no settings_file is found or sdk_key is incorrect

      def get_settings_file(is_via_webhook = false)
        is_valid_key = valid_number?(@account_id) || valid_string?(@account_id)

        unless is_valid_key && valid_string?(@sdk_key)
          puts 'account_id and sdk_key are required for fetching account settings. Aborting!'
          return '{}'
        end

        if is_via_webhook
          path = ::VWO::CONSTANTS::ENDPOINTS::WEBHOOK_SETTINGS_URL
        else
          path = ::VWO::CONSTANTS::ENDPOINTS::SETTINGS_URL
        end
        vwo_server_url = "#{PROTOCOL}://#{HOSTNAME}#{path}"

        settings_file_response = ::VWO::Utils::Request.get(vwo_server_url, params)

        if settings_file_response.code != '200'
          message = <<-DOC
            Request failed for fetching account settings.
            Got Status Code: #{settings_file_response.code}
            and message: #{settings_file_response.body}.
          DOC
          puts message
          return
        end
        settings_file_response.body
      rescue StandardError => e
        puts "Error fetching Settings File #{e}"
      end

      private

      def params
        {
          a: @account_id,
          i: @sdk_key,
          r: get_random_number,
          platform: 'server',
          'api-version' => 1
        }
      end
    end
  end
end

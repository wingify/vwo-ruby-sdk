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
require_relative '../utils/campaign'
require_relative '../utils/log_message'

class VWO
  module Services
    class SettingsFileProcessor
      include VWO::Enums
      include VWO::Utils::Campaign

      # Method to initialize settings_file and logger
      #
      # @params
      #  settings_file (Hash): Hash object of setting
      #  representing the settings_file.

      def initialize(settings_file)
        @settings_file = JSON.parse(settings_file)
      end

      # Processes the settings_file, assigns variation allocation range
      def process_settings_file
        (@settings_file['campaigns'] || []).each do |campaign|
          set_variation_allocation(campaign)
        end
        Utils::Logger.log(
          LogLevelEnum::DEBUG,
          'SETTINGS_FILE_PROCESSED',
          {
            '{file}' => FileNameEnum::SettingsFileProcessor,
            '{accountId}' => @settings_file['accountId']
          }
        )
      end

      def update_settings_file(settings_file)
        @settings_file = settings_file
        process_settings_file
      end

      def get_settings_file
        @settings_file
      end
    end
  end
end

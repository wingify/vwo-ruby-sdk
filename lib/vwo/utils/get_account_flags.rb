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

require_relative '../constants'

# Utility module for generating uuid
class VWO
  module Utils
    class GetAccountFlags
      @@instance = nil

      def self.get_instance
        @@instance = new if @@instance.nil?
        @@instance
      end

      def get_isNbv2_flag
        isNBv2 = false
        if @settings && @settings.key?('isNBv2') && @settings['isNBv2']
          isNBv2 = @settings['isNBv2']
        end
        return isNBv2
      end

      def get_isNB_flag
        isNB = false
        if @settings && @settings.key?('isNB') && @settings['isNB']
          isNB = @settings['isNB']
        end
        return isNB
      end

      def get_account_id
        account_id = nil
        if @settings && @settings.key?('accountId') && @settings['accountId']
          account_id = @settings['accountId']
        end
        return account_id
      end

      def set_settings(settings)
        @settings = settings
      end
    end
  end
end

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

require_relative '../logger'
require_relative '../enums'
require_relative '../constants'

# Utility module for helper math and random functions
class VWO
  module Utils
    module Function
      include VWO::Enums
      include VWO::CONSTANTS

      # @return[Float]
      def get_random_number
        rand
      end

      # @return[Integer]
      def get_current_unix_timestamp
        Time.now.to_i
      end

      # @return[Integer]
      def get_current_unix_timestamp_in_millis
        (Time.now.to_f * 1000).to_i
      end

      # @return[any, any]
      def get_key_value(obj)
        [obj.keys[0], obj.values[0]]
      end
    end
  end
end

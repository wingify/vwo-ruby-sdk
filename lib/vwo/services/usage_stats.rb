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

class VWO
  module Services
    class UsageStats
      attr_reader :usage_stats

      # Initialize the UsageStats
      def initialize(stats, is_development_mode = false)
        @usage_stats = {}
        return if is_development_mode

        @usage_stats = stats
        @usage_stats[:_l] = 1 if @usage_stats.length > 0
      end
    end
  end
end

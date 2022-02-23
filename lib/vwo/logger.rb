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

require 'logger'

class VWO
  class Logger
    @logger = nil
    @logger_instance = nil

    def self.get_instance(logger_instance = nil)
      @@logger ||= VWO::Logger.new(logger_instance)
    end

    def initialize(logger_instance)
      @@logger_instance = logger_instance || ::Logger.new(STDOUT)
    end

    # Override this method to handle logs in a custom manner
    def log(level, message, disable_logs = false)
      unless disable_logs
        @@logger_instance.log(level, message)
      end
    end

    def instance
      @@logger_instance
    end

    def level
      @@logger_instance.level
    end
  end
end

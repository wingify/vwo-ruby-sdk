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

require 'vwo_log_messages'

require_relative '../logger'

class VWO
  module Utils
    class Logger

      DEBUG = ::Logger::DEBUG
      INFO = ::Logger::INFO
      ERROR = ::Logger::ERROR
      WARN = ::Logger::WARN

      @@logs = nil
      @@api_name = 'api_name'

      def self.set_api_name(api_name)
        @@api_name = api_name
      end

      def self.get_log_message(logsType, message_type)
        if @@logs.nil?
          @@logs = VwoLogMessages.getMessage
        end

        if !@@logs[logsType].key?(message_type)
          return message_type
        end
        return @@logs[logsType][message_type]
      end

      def self.log(level, message_type, params, disable_logs = false)
        if disable_logs
          return
        end
        if level == DEBUG
          message = get_log_message('debug_logs', message_type)
        elsif level == INFO
          message = get_log_message('info_logs', message_type)
        elsif level == ERROR
          message = get_log_message('error_logs', message_type)
        elsif level == WARN
          message = get_log_message('warning_logs', message_type)
        else
          message = ""
        end
        message = message.dup

        if message && !message.empty?
          params.each {
            |key, value|
            if message.include? key
              message[key.to_s]= value.to_s
            end
          }
        end
        message = '[' + @@api_name + '] ' + message
        VWO::Logger.get_instance.log(level, message)
      end
    end
  end
end

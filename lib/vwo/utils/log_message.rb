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

      def self.get_log_message(logs_type, message_type)
        @@logs = VwoLogMessages.getMessage if @@logs.nil?

        return message_type unless @@logs[logs_type].key?(message_type)

        @@logs[logs_type][message_type]
      end

      def self.log(level, message_type, params, disable_logs = false)
        return if disable_logs

        message = case level
                  when DEBUG
                    get_log_message('debug_logs', message_type)
                  when INFO
                    get_log_message('info_logs', message_type)
                  when ERROR
                    get_log_message('error_logs', message_type)
                  when WARN
                    get_log_message('warning_logs', message_type)
                  else
                    ''
                  end
        message = message.dup

        if message && !message.empty?
          params.each do |key, value|
            message[key.to_s] = value.to_s if message.include? key
          end
        end
        message = "[#{@@api_name}] #{message}"
        VWO::Logger.get_instance.log(level, message)
      end
    end
  end
end

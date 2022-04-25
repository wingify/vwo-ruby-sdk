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
require_relative '../utils/request'
require_relative '../utils/log_message'

class VWO
  module Services
    class BatchEventsQueue
      include VWO::Enums

      def initialize(batch_config, is_development_mode = false)
        @is_development_mode = is_development_mode
        @logger = VWO::Utils::Logger
        @queue = []
        @queue_metadata = {}
        @batch_config = batch_config

        if batch_config[:request_time_interval]
          @request_time_interval = batch_config[:request_time_interval]
        else
          @request_time_interval = CONSTANTS::DEFAULT_REQUEST_TIME_INTERVAL
          @logger.log(
            LogLevelEnum::INFO,
            'EVENT_BATCH_DEFAULTS',
            {
              '{file}' => FileNameEnum::BATCH_EVENTS_QUEUE,
              '{parameter}' => 'request_time_interval',
              '{defaultValue}' => "#{@request_time_interval} ms"
            }
          )
        end

        if batch_config[:events_per_request]
          @events_per_request = batch_config[:events_per_request]
        else
          @events_per_request = CONSTANTS::DEFAULT_EVENTS_PER_REQUEST
          @logger.log(
            LogLevelEnum::INFO,
            'EVENT_BATCH_DEFAULTS',
            {
              '{file}' => FileNameEnum::BATCH_EVENTS_QUEUE,
              '{parameter}' => 'events_per_request',
              '{defaultValue}' => @events_per_request.to_s
            }
          )
        end

        @flush_callback = nil
        @flush_callback = batch_config[:flushCallback] if batch_config.key?(:flushCallback) && batch_config[:flushCallback].is_a?(Method)

        @dispatcher = batch_config[:dispatcher]
      end

      def create_new_batch_timer
        @timer = Time.now + @request_time_interval
      end

      def enqueue(event)
        return true if @is_development_mode

        @queue.push(event)
        update_queue_metadata(event)
        unless @timer
          create_new_batch_timer
          @thread = Thread.new { flush_when_request_times_up }
        end
        return unless @events_per_request == @queue.length

        flush
        kill_old_thread
      end

      def flush_when_request_times_up
        sleep(1) while @timer > Time.now
        flush
        kill_old_thread
      end

      def flush(manual = false)
        if @queue.length > 0
          @logger.log(
            LogLevelEnum::DEBUG,
            'EVENT_BATCH_BEFORE_FLUSHING',
            {
              '{file}' => FileNameEnum::BATCH_EVENTS_QUEUE,
              '{manually}' => manual ? 'manually' : '',
              '{length}' => @queue.length,
              '{timer}' => manual ? 'Timer will be cleared and registered again,' : '',
              '{accountId}' => @batch_config[:account_id]
            }
          )

          @dispatcher.call(@queue, @flush_callback)

          @logger.log(
            LogLevelEnum::INFO,
            'EVENT_BATCH_After_FLUSHING',
            {
              '{file}' => FileNameEnum::BATCH_EVENTS_QUEUE,
              '{manually}' => manual ? 'manually,' : '',
              '{length}' => @queue.length
            }
          )
          @queue_metadata = {}
          @queue = []
        else
          @logger.log(
            LogLevelEnum::INFO,
            'Batch queue is empty. Nothing to flush.',
            { '{file}' => FILE }
          )
        end

        clear_request_timer
        @old_thread = @thread if !manual && @thread
        true
      end

      def clear_request_timer
        @timer = nil
      end

      def kill_thread
        @thread&.kill
      end

      def kill_old_thread
        @old_thread&.kill
      end

      def update_queue_metadata(event)
        case event[:eT]
        when 1
          @queue_metadata[VWO::EVENTS::TRACK_USER] = 0 unless @queue_metadata.key?(VWO::EVENTS::TRACK_USER)
          @queue_metadata[VWO::EVENTS::TRACK_USER] = @queue_metadata[VWO::EVENTS::TRACK_USER] + 1
        when 2
          @queue_metadata[VWO::EVENTS::TRACK_GOAL] = 0 unless @queue_metadata.key?(VWO::EVENTS::TRACK_GOAL)
          @queue_metadata[VWO::EVENTS::TRACK_GOAL] = @queue_metadata[VWO::EVENTS::TRACK_GOAL] + 1
        when 3
          @queue_metadata[VWO::EVENTS::PUSH] = 0 unless @queue_metadata.key?(VWO::EVENTS::PUSH)
          @queue_metadata[VWO::EVENTS::PUSH] = @queue_metadata[VWO::EVENTS::PUSH] + 1
        end
      end
    end
  end
end

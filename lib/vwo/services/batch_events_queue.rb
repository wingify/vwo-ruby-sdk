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
require_relative '../utils/request'

class VWO
  module Services
    class BatchEventsQueue
      include VWO::Enums

      def initialize(batch_config, is_development_mode = false)
        @is_development_mode = is_development_mode
        @logger = VWO::Logger.get_instance
        @queue = []
        @queue_metadata = {}
        @batch_config = batch_config

        if batch_config[:request_time_interval]
          @request_time_interval = batch_config[:request_time_interval]
        else
          @request_time_interval = CONSTANTS::DEFAULT_REQUEST_TIME_INTERVAL
          @logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::EVENT_BATCHING_INSUFFICIENT,
              file: FileNameEnum::BatchEventsQueue,
              key: 'request_time_interval'
            )
          )
        end

        if batch_config[:events_per_request]
          @events_per_request = batch_config[:events_per_request]
        else
          @events_per_request = CONSTANTS::DEFAULT_EVENTS_PER_REQUEST
          @logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::EVENT_BATCHING_INSUFFICIENT,
              file: FileNameEnum::BatchEventsQueue,
              key: 'events_per_request'
            )
          )
        end

        @flush_callback = nil
        if batch_config.key?(:flushCallback) && batch_config[:flushCallback].is_a?(Method)
          @flush_callback = batch_config[:flushCallback]
        end

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
          @thread = Thread.new{flush_when_request_times_up}
        end
        if @events_per_request === @queue.length()
          flush
          kill_old_thread
        end
      end

      def flush_when_request_times_up
        while @timer > Time.now
          sleep(1)
        end
        flush
        kill_old_thread
      end

      def flush(manual = false)
        if @queue.length() > 0
          @logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::BEFORE_FLUSHING,
              file: FileNameEnum::BatchEventsQueue,
              manually: manual ? 'manually' : '',
              length: @queue.length(),
              timer: manual ? 'Timer will be cleared and registered again,' : '',
              queue_metadata: @queue_metadata
            )
          )

          @dispatcher.call(@queue, @flush_callback)
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::AFTER_FLUSHING,
              file: FILE,
              manually: manual ? 'manually,' : '',
              length: @queue.length(),
              queue_metadata: @queue_metadata
            )
          )
          @queue_metadata = {}
          @queue = []
        else
          @logger.log(
            LogLevelEnum::INFO,
            format(
              'Batch queue is empty. Nothing to flush.',
              file: FILE
            )
          )
        end

        clear_request_timer
        unless manual
          if @thread
            @old_thread = @thread
          end
        end
        true
      end

      def clear_request_timer
        @timer = nil
      end

      def kill_thread
        if @thread
          @thread.kill
        end
      end

      def kill_old_thread
        if @old_thread
          @old_thread.kill
        end
      end

      def update_queue_metadata(event)
        if event[:eT] == 1
          unless @queue_metadata.key?(VWO::EVENTS::TRACK_USER)
            @queue_metadata[VWO::EVENTS::TRACK_USER] = 0
          end
          @queue_metadata[VWO::EVENTS::TRACK_USER] = @queue_metadata[VWO::EVENTS::TRACK_USER] + 1
        elsif event[:eT] == 2
          unless @queue_metadata.key?(VWO::EVENTS::TRACK_GOAL)
            @queue_metadata[VWO::EVENTS::TRACK_GOAL] = 0
          end
          @queue_metadata[VWO::EVENTS::TRACK_GOAL] = @queue_metadata[VWO::EVENTS::TRACK_GOAL] + 1
        elsif event[:eT] == 3
          unless @queue_metadata.key?(VWO::EVENTS::PUSH)
            @queue_metadata[VWO::EVENTS::PUSH] = 0
          end
          @queue_metadata[VWO::EVENTS::PUSH] = @queue_metadata[VWO::EVENTS::PUSH] + 1
        end
      end
    end
  end
end

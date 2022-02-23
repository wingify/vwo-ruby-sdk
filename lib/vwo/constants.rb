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
  module CONSTANTS
    API_VERSION = 1
    PLATFORM = 'server'
    SEED_VALUE = 1
    MAX_TRAFFIC_PERCENT = 100
    MAX_TRAFFIC_VALUE = 10_000
    MAX_RANGE = 10000
    STATUS_RUNNING = 'RUNNING'
    # rubocop:disable Style/ExpandPathArguments
    LIBRARY_PATH =  File.expand_path('../..', __FILE__)
    # rubocop:enable Style/ExpandPathArguments
    HTTP_PROTOCOL = 'http://'
    HTTPS_PROTOCOL = 'https://'
    URL_NAMESPACE = '6ba7b811-9dad-11d1-80b4-00c04fd430c8'
    SDK_VERSION = '1.29.0'
    SDK_NAME = 'ruby'
    VWO_DELIMITER = '_vwo_'
    MAX_EVENTS_PER_REQUEST = 5000
    MIN_EVENTS_PER_REQUEST = 1
    DEFAULT_EVENTS_PER_REQUEST = 100
    DEFAULT_REQUEST_TIME_INTERVAL = 600 # 10 * 60(secs) = 600 secs i.e. 10 minutes
    MIN_REQUEST_TIME_INTERVAL = 2

    module ENDPOINTS
      BASE_URL = 'dev.visualwebsiteoptimizer.com'
      SETTINGS_URL = '/server-side/settings'
      WEBHOOK_SETTINGS_URL = '/server-side/pull'
      TRACK_USER = '/server-side/track-user'
      TRACK_GOAL = '/server-side/track-goal'
      PUSH = '/server-side/push'
      BATCH_EVENTS = '/server-side/batch-events'
      EVENTS = '/events/t'
    end

    module EVENTS
      TRACK_USER = 'track-user'
      TRACK_GOAL = 'track-goal'
      PUSH = 'push'
    end

    module DATATYPE
      NUMBER = 'number'
      STRING = 'string'
      FUNCTION = 'function'
      BOOLEAN = 'boolean'
    end

    module GoalTypes
      REVENUE = 'REVENUE_TRACKING'
      CUSTOM = 'CUSTOM_GOAL'
    end

    module VariableTypes
      STRING = 'string'
      INTEGER = 'integer'
      DOUBLE = 'double'
      BOOLEAN = 'boolean'
      JSON = 'json'
    end

    module Hooks
      DECISION_TYPES = {
        'CAMPAIGN_DECISION' => 'CAMPAIGN_DECISION'
      }
    end

    RUBY_VARIABLE_TYPES = {
      'string' => [String],
      'integer' => [Integer],
      'double' => [Float],
      'boolean' => [TrueClass, FalseClass],
      'json' => [Hash]
    }

    GOAL_TYPES = {
      'REVENUE' => 'REVENUE_TRACKING',
      'CUSTOM' => 'CUSTOM_GOAL',
      'ALL' => 'ALL'
    }

    module ApiMethods
      ACTIVATE = 'activate'
      GET_VARIATION_NAME = 'get_variation_name'
      TRACK = 'track'
      IS_FEATURE_ENABLED = 'is_feature_enabled'
      GET_FEATURE_VARIABLE_VALUE = 'get_feature_variable_value'
      PUSH = 'push'
      GET_AND_UPDATE_SETTINGS_FILE = 'get_and_update_settings_file'
      FLUSH_EVENTS = 'flush_events'
      OPT_OUT = 'opt_out'
    end

    module PushApi
      TAG_VALUE_LENGTH = 255
      TAG_KEY_LENGTH = 255
    end

    module CampaignTypes
      VISUAL_AB = 'VISUAL_AB'
      FEATURE_TEST = 'FEATURE_TEST'
      FEATURE_ROLLOUT = 'FEATURE_ROLLOUT'
    end

    module EventEnum
      VWO_VARIATION_SHOWN = 'vwo_variationShown'
      VWO_SYNC_VISITOR_PROP = 'vwo_syncVisitorProp'
    end
  end
end

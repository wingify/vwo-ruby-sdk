# Copyright 2019-2020 Wingify Software Pvt. Ltd.
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
    STATUS_RUNNING = 'RUNNING'
    # rubocop:disable Style/ExpandPathArguments
    LIBRARY_PATH =  File.expand_path('../..', __FILE__)
    # rubocop:enable Style/ExpandPathArguments
    HTTP_PROTOCOL = 'http://'
    HTTPS_PROTOCOL = 'https://'
    URL_NAMESPACE = '6ba7b811-9dad-11d1-80b4-00c04fd430c8'
    SDK_VERSION = '1.5.0'
    SDK_NAME = 'ruby'

    module ENDPOINTS
      BASE_URL = 'dev.visualwebsiteoptimizer.com'
      ACCOUNT_SETTINGS = '/server-side/settings'
      TRACK_USER = '/server-side/track-user'
      TRACK_GOAL = '/server-side/track-goal'
      PUSH = '/server-side/push'
    end

    module EVENTS
      TRACK_USER = 'track-user'
      TRACK_GOAL = 'track-goal'
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
    end

    RUBY_VARIABLE_TYPES = {
      'string' => [String],
      'integer' => [Integer],
      'double' => [Float],
      'boolean' => [TrueClass, FalseClass]
    }

    module ApiMethods
      ACTIVATE = 'activate'
      GET_VARIATION_NAME = 'get_variation_name'
      TRACK = 'track'
      IS_FEATURE_ENABLED = 'is_feature_enabled'
      GET_FEATURE_VARIABLE_VALUE = 'get_feature_variable_value'
      PUSH = 'push'
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
  end
end

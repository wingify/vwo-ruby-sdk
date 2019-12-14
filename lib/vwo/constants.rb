# Copyright 2019 Wingify Software Pvt. Ltd.
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
    LIBRARY_PATH =  File.expand_path('../..', __dir__)
    HTTP_PROTOCOL = 'http://'
    HTTPS_PROTOCOL = 'https://'
    URL_NAMESPACE = '6ba7b811-9dad-11d1-80b4-00c04fd430c8'
    SDK_VERSION = '1.3.0'
    SDK_NAME = 'ruby'

    module ENDPOINTS
      BASE_URL = 'dev.visualwebsiteoptimizer.com'
      ACCOUNT_SETTINGS = '/server-side/settings'
      TRACK_USER = '/server-side/track-user'
      TRACK_GOAL = '/server-side/track-goal'
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

    module APIMETHODS
      CREATE_INSTANCE = 'CREATE_INSTANCE'
      ACTIVATE = 'ACTIVATE'
      GET_VARIATION = 'GET_VARIATION'
      TRACK = 'TRACK'
    end

    module GOALTYPES
      REVENUE = 'REVENUE_TRACKING'
      CUSTOM = 'CUSTOM_GOAL'
    end
  end
end

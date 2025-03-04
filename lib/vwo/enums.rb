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

require 'logger'

class VWO
  module Enums
    module OperandValueTypesName
      REGEX = 'regex'
      WILDCARD = 'wildcard'
      LOWER = 'lower'
      EQUALS = 'equals'
      GREATER_THAN="gt"
      LESS_THAN="lt"
      GREATER_THAN_EQUAL_TO="gte"
      LESS_THAN_EQUAL_TO="lte"
    end

    module OperandValueTypes
      LOWER = 'lower'
      CONTAINS = 'contains'
      STARTS_WITH = 'starts_with'
      ENDS_WITH = 'ends_with'
      REGEX = 'regex'
      EQUALS = 'equals'
      LESS_THAN = 'less_than'
      GREATER_THAN = 'greater_than'
      LESS_THAN_EQUAL_TO = 'less_than_equal_to'
      GREATER_THAN_EQUAL_TO = 'greater_than_equal_to'
    end

    module OperatorTypes
      AND = 'and'
      OR = 'or'
      NOT = 'not'
    end

    module OperandTypes
      CUSTOM_VARIABLE = 'custom_variable'
      USER = 'user'
    end

    module OperandValuesBooleanTypes
      TRUE = 'true'
      FALSE = 'false'
    end

    module StatusEnum
      PASSED = 'passed'
      FAILED = 'failed'
    end

    module SegmentationTypeEnum
      WHITELISTING = 'whitelisting'
      PRE_SEGMENTATION = 'pre-segmentation'
    end

    module FileNameEnum
      VWO_PATH = 'vwo'
      UTIL_PATH = 'vwo/utils'

      VWO = "#{VWO_PATH}/vwo"
      BUCKETER = "#{VWO_PATH}/core/bucketer"
      VARIATION_DECIDER = "#{VWO_PATH}/core/variation_decider"
      EVENT_DISPATCHER = "#{VWO_PATH}/services/event_dispatcher"
      SEGMENT_EVALUATOR = "#{VWO_PATH}/services/segment_evaluator"
      LOGGER = "#{VWO_PATH}/logger"
      SETTINGS_FILE_PROCESSOR = "#{VWO_PATH}/services/settings_file_processor"
      BATCH_EVENTS_QUEUE = "#{VWO_PATH}/services/batch_events_queue"
      BATCH_EVENTS_DISPATCHER = "#{VWO_PATH}/services/batch_events_dispatcher"

      CAMPAIGN_UTIL = "#{UTIL_PATH}/campaign"
      FUNCTION_UTIL = "#{UTIL_PATH}/function"
      FEATURE_UTIL = "#{UTIL_PATH}/feature"
      IMPRESSION_UTIL = "#{UTIL_PATH}/impression"
      UUID_UTIL = "#{UTIL_PATH}/uuid"
      VALIDATE_UTIL = "#{UTIL_PATH}/validations"
      CUSTOM_DIMENSTIONS_UTIL = "#{UTIL_PATH}/custom_dimensions_util"
    end

    module LogLevelEnum
      INFO = ::Logger::INFO
      DEBUG = ::Logger::DEBUG
      WARNING = ::Logger::WARN
      ERROR = ::Logger::ERROR
    end
  end
end

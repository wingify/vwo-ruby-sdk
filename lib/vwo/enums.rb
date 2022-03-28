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

# rubocop:disable Metrics/LineLength

require 'logger'

class VWO
  module Enums
    module OperandValueTypesName
      REGEX = 'regex'
      WILDCARD = 'wildcard'
      LOWER = 'lower'
      EQUALS = 'equals'
    end

    module OperandValueTypes
      LOWER = 'lower'
      CONTAINS = 'contains'
      STARTS_WITH = 'starts_with'
      ENDS_WITH = 'ends_with'
      REGEX = 'regex'
      EQUALS = 'equals'
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

      VWO = VWO_PATH + '/vwo'
      Bucketer = VWO_PATH + '/core/bucketer'
      VariationDecider = VWO_PATH + '/core/variation_decider'
      EventDispatcher = VWO_PATH + '/services/event_dispatcher'
      SegmentEvaluator = VWO_PATH + '/services/segment_evaluator'
      Logger = VWO_PATH + '/logger'
      SettingsFileProcessor = VWO_PATH + '/services/settings_file_processor'
      BatchEventsQueue = VWO_PATH + '/services/batch_events_queue'
      BatchEventsDispatcher = VWO_PATH + '/services/batch_events_dispatcher'

      CampaignUtil = UTIL_PATH + '/campaign'
      FunctionUtil = UTIL_PATH + '/function'
      FeatureUtil = UTIL_PATH + '/feature'
      ImpressionUtil = UTIL_PATH + '/impression'
      UuidUtil = UTIL_PATH + '/uuid'
      ValidateUtil = UTIL_PATH + '/validations'
      CustomDimensionsUtil = UTIL_PATH + '/custom_dimensions_util'
    end

    module LogLevelEnum
      INFO = ::Logger::INFO
      DEBUG = ::Logger::DEBUG
      WARNING = ::Logger::WARN
      ERROR = ::Logger::ERROR
    end
  end
end
# rubocop:enable Metrics/LineLength

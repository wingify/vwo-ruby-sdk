# Copyright 2019-2021 Wingify Software Pvt. Ltd.
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

require 'test/unit'
require 'json'
require_relative '../lib/vwo/services/segment_evaluator'

SEGMENT_EXPECTATIONS = JSON.load(File.open(File.join(File.dirname(__FILE__), 'data/segment_expectations.json')))

class SegmentEvaluatorTest < Test::Unit::TestCase
  def test_segmentation_expectations
    SEGMENT_EXPECTATIONS.each do |_test_group_key, test_group_value|
      test_group_value.each do |_test_case_key, test_case_value|
        custom_variables = test_case_value['custom_variables'] || test_case_value['variation_targeting_variables']
        dsl = test_case_value['dsl']
        expectation = test_case_value['expectation']
        result = VWO::Services::SegmentEvaluator.new.evaluate("dummyCampaignKey", "dummyUserId", dsl, custom_variables)
        assert_equal(result, expectation)
      end
    end
  end
end

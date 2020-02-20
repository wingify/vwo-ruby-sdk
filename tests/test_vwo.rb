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

require 'json'
require_relative '../lib/vwo'
require 'logger'
require 'test/unit'

class Object
  def stub_and_raise(fn_name, raise_error)
    self.singleton_class.send(:define_method, fn_name.to_s) do
      raise raise_error
    end
  end
end

# from .data.settings_files import SETTINGS_FILES
# from .data.settings_file_and_user_expectations import USER_EXPECTATIONS

SETTINGS_FILE = JSON.load(File.open(File.join(File.dirname(__FILE__), 'data/settings.json')))
USER_EXPECTATIONS = JSON.load(File.open(File.join(File.dirname(__FILE__), 'data/user_expectations.json')))


class VWO
  class Logger
    def log(level, message)
      # no-op
    end
  end
end

class VWOTest < Test::Unit::TestCase

  def set_up(config_variant = 'AB_T_50_W_50_50')
    @user_id = rand.to_s
    @vwo = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE[config_variant] || {}))
    @campaign_key = config_variant
    begin
      @goal_identifier = SETTINGS_FILE[config_variant]['campaigns'][0]['goals'][0]['identifier']
    rescue StandardError => _e
      @goal_identifier = nil
    end
  end

  def mock_track(campaign_key, user_id, goal_identifier, *args)
    revenue_value = nil
    custom_variables = nil
    if args[0].is_a?(Hash)
      revenue_value = args[0]['revenue_value'] || args[0][:revenue_value]
      custom_variables = args[0]['custom_variables'] || args[0][:custom_variables]
    elsif args.is_a?(Array)
      revenue_value = args[0]
      custom_variables = args[1]
    end
    if custom_variables
      return {
        'campaign_key' => campaign_key,
        'user_id' => user_id,
        'goal_identifier' => goal_identifier,
        'revenue_value' => revenue_value,
        'custom_variables' => custom_variables
      }
    end
  end

  # Test initialization
  def test_init_vwo_with_invalid_settings_file
    set_up('EMPTY_SETTINGS_FILE')
    assert_equal(@vwo.is_instance_valid, false)
  end

  # Test get_variation
  def test_get_variation_name_invalid_params
    set_up('EMPTY_SETTINGS_FILE')
    assert_equal(@vwo.get_variation_name(123, 456), nil)
  end

  def test_get_variation_with_no_campaign_key_found
    set_up('AB_T_50_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name('NO_SUCH_CAMPAIGN_KEY', test['user']), nil)
    end
  end

  def test_get_variation_invalid_config
    set_up('FR_T_0_W_100')
    assert_equal(@vwo.get_variation_name(@user_id, 'some_campaign'), nil)
  end


  def test_get_variation_against_campaign_traffic_50_and_split_50_50
    set_up('AB_T_50_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end


  def test_get_variation_against_campaign_traffic_100_and_split_50_50
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_100_and_split_20_80
    set_up('AB_T_100_W_20_80')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_20_and_split_10_90
    set_up('AB_T_20_W_10_90')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_100_and_split_0_100
    set_up('AB_T_100_W_0_100')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_100_and_split_33_x3
    set_up('AB_T_100_W_33_33_33')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_name_against_campaign_traffic_75_and_split_10_TIMES_10
    set_up('T_75_W_10_TIMES_10')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  # Test activate
  def test_activate_invalid_params
    set_up()
    assert_equal(@vwo.activate(123, 456), nil)
  end

  def test_activate_invalid_config
    set_up('EMPTY_SETTINGS_FILE')
    assert_equal(@vwo.activate(@user_id, 'some_campaign'), nil)
  end

  def test_activate_with_no_campaign_key_found
    set_up('AB_T_50_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate('NO_SUCH_CAMPAIGN_KEY', test['user']), nil)
    end
  end

  def test_activate_against_campaign_traffic_50_and_split_50_50
    set_up('AB_T_50_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_100_and_split_50_50
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_100_and_split_20_80
    set_up('AB_T_100_W_20_80')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_20_and_split_10_90
    set_up('AB_T_20_W_10_90')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_100_and_split_0_100
    set_up('AB_T_100_W_0_100')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_100_and_split_33_x3
    set_up('AB_T_100_W_33_33_33')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key,test['user']), test['variation'])
    end
  end

  # Test track
  def test_track_invalid_params
    set_up()
    assert_equal(@vwo.track(123, 456, 789), false)
  end

  def test_track_invalid_config
    set_up('EMPTY_SETTINGS_FILE')
    assert_equal(@vwo.track(@user_id, 'somecampaign', 'somegoal'), false)
  end

  def test_track_with_no_campaign_key_found
    set_up('AB_T_50_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track('NO_SUCH_CAMPAIGN_KEY', test['user'], @goal_identifier), false)
    end
  end

  def test_track_with_no_goal_identifier_found
    set_up('AB_T_50_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], 'NO_SUCH_GOAL_IDENTIFIER'), false)
    end
  end

  def test_track_wrong_campaign_type_passed
    set_up('FR_T_0_W_100')
    result = @vwo.track('FR_T_0_W_100', 'user', 'some_goal_identifier')
    assert_equal(result, false)
  end

  def test_track_against_campaign_traffic_50_and_split_50_50
    set_up('AB_T_50_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_r_int
    # It's goal_type is revenue, so test revenue
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, 23), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_r_float
    # It's goal_type is revenue, so test revenue
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, 23.3), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_r_str
    # It's goal_type is revenue, so test revenue
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, '23.3'), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_no_r
    # It's goal_type is revenue, so test revenue
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), false)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_options
    # It's goal_type is revenue, so test revenue
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, { 'revenue_value' => 23 }), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_20_80
    set_up('AB_T_100_W_20_80')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_20_and_split_10_90
    set_up('AB_T_20_W_10_90')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_0_100
    set_up('AB_T_100_W_0_100')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_33_x3
    set_up('AB_T_100_W_33_33_33')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), !test['variation'].nil?)
    end
  end

  def test_get_settings
    set_up('AB_T_50_W_50_50')
    assert_not_nil(@vwo.get_settings)
  end

  # Test.feature_enabled? on Feature-rollout
  def test_feature_enabled_wrong_campaign_key_passed
    set_up('FR_T_0_W_100')
    result = @vwo.feature_enabled?('not_a_campaign_key', 'user')
    assert_equal(result, false)
  end

  def test_feature_enabled_wrong_campaign_type_passed
    set_up('AB_T_50_W_50_50')
    result = @vwo.feature_enabled?('AB_T_50_W_50_50', 'user')
    assert_equal(result, false)
  end

  def test_feature_enabled_invalid_config
    set_up('EMPTY_SETTINGS_FILE')
    assert_equal(@vwo.feature_enabled?(@user_id, 'some_campaign'), false)
  end

  def test_feature_enabled_wrong_parmas_passed
    set_up('FR_T_0_W_100')
    assert_equal(@vwo.feature_enabled?(123, 456), false)
  end

  def test_feature_enabled_FR_W_0
    set_up('FR_T_0_W_100')
    USER_EXPECTATIONS['T_0_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FR_T_0_W_100', test['user']), !test['variation'].nil?)
    end
  end
  
  def test_feature_enabled_FR_W_25
    set_up('FR_T_25_W_100')
    USER_EXPECTATIONS['T_25_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FR_T_25_W_100', test['user']), !test['variation'].nil?)
    end
  end
  
  def test_feature_enabled_FR_W_50
    set_up('FR_T_50_W_100')
    USER_EXPECTATIONS['T_50_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FR_T_50_W_100', test['user']), !test['variation'].nil?)
    end
  end
  
  def test_feature_enabled_FR_W_75
    set_up('FR_T_75_W_100')
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FR_T_75_W_100', test['user']), !test['variation'].nil?)
    end
  end
  
  def test_feature_enabled_FR_W_100
    set_up('FR_T_100_W_100')
    USER_EXPECTATIONS['T_100_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FR_T_100_W_100', test['user']), !test['variation'].nil?)
    end
  end
  
  def test_feature_enabled_FT_T_75_W_10_20_30_40
    set_up('FT_T_75_W_10_20_30_40')
    is_feature_not_enabled_variations = ['Control']
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FT_T_75_W_10_20_30_40', test['user']), !test['variation'].nil? && !is_feature_not_enabled_variations.include?(test['variation']))
    end
  end
  
  # Test get_feature_variable_value from rollout
  def test_get_feature_variable_value_boolean_from_rollout
    set_up('FR_T_75_W_100')
    result = nil
    boolean_variable = USER_EXPECTATIONS['ROLLOUT_VARIABLES']['BOOLEAN_VARIABLE']
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FR_T_75_W_100',
        'BOOLEAN_VARIABLE',
        test['user']
      )
    end
    assert_equal(result, boolean_variable) if result
  end
  
  # Test get_feature_variable_value from rollout
  def test_get_feature_variable_value_type_string_from_rollout
    set_up('FR_T_75_W_100')
    string_variable = USER_EXPECTATIONS['ROLLOUT_VARIABLES']['STRING_VARIABLE']
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FR_T_75_W_100',
        'STRING_VARIABLE',
        test['user']
      )
      assert_equal(result, string_variable) if result
    end
  end
  
  # Test get_feature_variable_value from rollout
  def test_get_feature_variable_value_type_boolean_from_rollout
    set_up('FR_T_75_W_100')
    double_variable = USER_EXPECTATIONS['ROLLOUT_VARIABLES']['DOUBLE_VARIABLE']
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FR_T_75_W_100',
        'DOUBLE_VARIABLE',
        test['user']
      )
      assert_equal(result, double_variable) if result
    end
  end
  
  # Test get_feature_variable_value from rollout
  def test_get_feature_variable_value_type_integer_from_rollout
    set_up('FR_T_75_W_100')
    result = nil
    integer_value = USER_EXPECTATIONS['ROLLOUT_VARIABLES']['INTEGER_VARIABLE']
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FR_T_75_W_100',
        'INTEGER_VARIABLE',
        test['user']
      )
    end
    assert_equal(result, integer_value) if result
  end
  
  
  # Test get_feature_variable_value from feature test from different feature splits
  def test_get_feature_variable_value_type_string_from_feature_test_t_0
    set_up('FT_T_0_W_10_20_30_40')
    result = nil
    string_variable = USER_EXPECTATIONS['STRING_VARIABLE']
    USER_EXPECTATIONS['T_0_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FT_T_0_W_10_20_30_40',
        'STRING_VARIABLE',
        test['user']
      )
    end
    assert_equal(result, string_variable[test['variation']]) if result
  end

  def test_get_feature_variable_value_type_string_from_feature_test_t_25
    set_up('FT_T_25_W_10_20_30_40')
    result = nil
    string_variable = USER_EXPECTATIONS['STRING_VARIABLE']
    USER_EXPECTATIONS['T_25_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FT_T_25_W_10_20_30_40',
        'STRING_VARIABLE',
        test['user']
      )
    end
    assert_equal(result, string_variable[test['variation']]) if result
  end
  
  def test_get_feature_variable_value_type_string_from_feature_test_t_50
    set_up('FT_T_50_W_10_20_30_40')
    string_variable = USER_EXPECTATIONS['STRING_VARIABLE']
    USER_EXPECTATIONS['T_50_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FT_T_50_W_10_20_30_40',
        'STRING_VARIABLE',
        test['user']
      )
      assert_equal(result, string_variable[test['variation']]) if result
    end
  end
  
  def test_get_feature_variable_value_type_string_from_feature_test_t_75
    set_up('FT_T_75_W_10_20_30_40')
    string_variable = USER_EXPECTATIONS['STRING_VARIABLE']
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FT_T_75_W_10_20_30_40',
        'STRING_VARIABLE',
        test['user']
      )
      assert_equal(result, string_variable[test['variation']]) if result
    end
  end
  
  def test_get_feature_variable_value_type_string_from_feature_test_t_100
    set_up('FT_T_100_W_10_20_30_40')
    string_variable = USER_EXPECTATIONS['STRING_VARIABLE']
    USER_EXPECTATIONS['T_100_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FT_T_100_W_10_20_30_40',
        'STRING_VARIABLE',
        test['user']
      )
      assert_equal(result, string_variable[test['variation']]) if result
    end
  end
  
  def test_get_feature_variable_value_type_string_from_feature_test_t_100_isFeatureEnalbed
    # isFeatureEnalbed is false for variation-1 and variation-3,
    # should return variable from Control
    set_up('FT_T_100_W_10_20_30_40_IFEF')
    string_variable = USER_EXPECTATIONS['STRING_VARIABLE']
    USER_EXPECTATIONS['T_100_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FT_T_100_W_10_20_30_40_IFEF',
        'STRING_VARIABLE',
        test['user']
      )
      variation_name = test['variation']
      variation_name = 'Control' if ['Variation-1', 'Variation-3'].include?(variation_name)
      assert_equal(result, string_variable[variation_name]) if result
    end
  end
  
  def test_get_feature_variable_wrong_variable_types
    set_up('FR_WRONG_VARIABLE_TYPE')
    tests = [
      ["STRING_TO_INTEGER", 123, "integer", Integer],
      ["STRING_TO_FLOAT", 123.456, "double", Float],
      ["BOOLEAN_TO_STRING", "true", "string", String],
      ["INTEGER_TO_STRING", "24", "string", String],
      ["INTEGER_TO_FLOAT", 24.0, "double", Float],
      ["FLOAT_TO_STRING", "24.24", "string", String],
      ["FLOAT_TO_INTEGER", 24, "integer", Integer]
    ]
    tests.each do |test|
      result = @vwo.get_feature_variable_value(
        'FR_WRONG_VARIABLE_TYPE',
        test[0],
        'Zin'
      )
      assert_equal(result, test[1])
      assert_equal(result.public_send(:is_a?, test[3]), true)
    end
  end
  
  # Testing private method _get_feature_variable

  def test_get_feature_variable_wrong_variable_types_return_none
    set_up('FR_WRONG_VARIABLE_TYPE')
    tests = [["WRONG_BOOLEAN", nil, "boolean", nil]]
    tests.each do |test|
      result = @vwo.get_feature_variable_value(
        'FR_WRONG_VARIABLE_TYPE',
        test[0],
        'Zin'
      )
      assert_equal(result, test[1])
    end
  end
  
  def test_get_feature_variable_invalid_params
    set_up('FR_T_100_W_100')
    assert_equal(@vwo.get_feature_variable_value(123, 456, 789), nil)
  end
  
  def test_get_feature_variable_invalid_config
    set_up('EMPTY_SETTINGS_FILE')
    assert_equal(
      @vwo.get_feature_variable_value(
        'campaign_key',
        'variable_key',
        'user_id'
      ), nil
    )
  end
  
  def test_get_feature_variable_invalid_campaing_key
    set_up('FR_T_100_W_100')
    assert_equal(
      @vwo.get_feature_variable_value(
        'not_a_campaign',
        'STRING_VARIABLE',
        'Zin'
      ), nil
    )
  end
  
  def test_get_feature_variable_invalid_campaing_type
    set_up('AB_T_50_W_50_50')
    assert_equal(
      @vwo.get_feature_variable_value(
        'AB_T_50_W_50_50',
        'STRING_VARIABLE',
        'Zin'
      ), nil
    )
  end
  
  # test each api raises exception
  def test_activate_raises_exception
    set_up()
    @vwo.stub_and_raise(:valid_string?, StandardError)
    assert_equal(nil, @vwo.activate('SOME_CAMPAIGN', 'USER'))
  end

  def test_get_variation_name_raises_exception
    set_up()
    @vwo.stub_and_raise(:valid_string?, StandardError)
    assert_equal(nil, @vwo.get_variation_name('SOME_CAMPAIGN', 'USER'))
  end

  def test_track_raises_exception
    set_up()
    @vwo.stub_and_raise(:valid_string?, StandardError)
    assert_equal(false, @vwo.track('SOME_CAMPAIGN', 'USER', 'GOAL'))
  end

  def test_feature_enabled_raises_exception
    set_up()
    @vwo.stub_and_raise(:valid_string?, StandardError)
    assert_equal(false, @vwo.feature_enabled?('SOME_CAMPAIGN', 'USER'))
  end

  def test_get_feature_variable_raises_exception
    set_up()
    @vwo.stub_and_raise(:valid_string?, StandardError)
    assert_equal(nil, @vwo.get_feature_variable_value('SOME_CAMPAIGN','VARIABLE_KEY','USER_ID'))
  end

  def test_push_raises_exception
    set_up()
    @vwo.stub_and_raise(:valid_string?, StandardError)
    assert_equal(false, @vwo.push('SOME_CAMPAIGN', 'VARIABLE_KEY','USER_ID'))
  end

  def test_vwo_initialized_with_provided_log_level_DEBUG
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: Logger::DEBUG })
    assert_equal(vwo_instance.logger.level, Logger::DEBUG)
  end

  def test_vwo_initialized_with_provided_log_level_WARNING
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: Logger::WARN })
    assert_equal(vwo_instance.logger.level, Logger::WARN)
  end
  
  # test activate with pre-segmentation
  def test_activate_with_no_custom_variables_fails
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_50_W_50_50_WS']), { log_level: Logger::DEBUG })
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(vwo_instance.activate('T_50_W_50_50_WS', test['user']), nil)
    end
  end

  def test_activate_with_no_dsl_remains_unaffected
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: Logger::DEBUG })
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(
        vwo_instance.activate('AB_T_50_W_50_50', test['user'], { custom_variables: true_custom_variables }),
        test['variation']
      )
    end
  end

  def test_activate_with_presegmentation_true
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_100_W_50_50_WS']), { log_level: Logger::DEBUG })
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }

    USER_EXPECTATIONS['AB_T_100_W_50_50'].each do |test|
      assert_equal(
        vwo_instance.activate('T_100_W_50_50_WS', test['user'], { custom_variables: true_custom_variables }),
        test['variation']
      )
    end
  end

  def test_activate_with_presegmentation_false
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_100_W_50_50_WS']), { log_level: Logger::DEBUG })
    false_custom_variables = {
      'a' => 987123,
      'world' => 'hello'
    }
    USER_EXPECTATIONS['AB_T_100_W_50_50'].each do |test|
      assert_equal(
        vwo_instance.activate('T_100_W_50_50_WS', test['user'], { custom_variables: false_custom_variables }),
        nil
      )
    end
  end

  def test_get_variation_name_with_no_custom_variables_fails
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_100_W_50_50_WS']), { log_level: Logger::DEBUG })
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(
        vwo_instance.get_variation_name('T_50_W_50_50_WS', test['user']),
        nil
      )
    end
  end

  def test_get_variation_name_with_no_dsl_remains_unaffected
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_50_W_50_50_WS']), { log_level: Logger::DEBUG })
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(
        vwo_instance.get_variation_name('T_50_W_50_50_WS', test['user'], { custom_variables: true_custom_variables }),
        test['variation']
      )
    end
  end

  def test_get_variation_name_with_presegmentation_true
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_100_W_50_50_WS']), { log_level: Logger::DEBUG })
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    USER_EXPECTATIONS['AB_T_100_W_50_50'].each do |test|
      assert_equal(
        vwo_instance.get_variation_name('T_100_W_50_50_WS', test['user'], { custom_variables: true_custom_variables }),
        test['variation']
      )
    end
  end

  def test_get_variation_name_with_presegmentation_false
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_100_W_50_50_WS']), { log_level: Logger::DEBUG })
    false_custom_variables = {
      'a' => 987123,
      'world' => 'hello'
    }
    USER_EXPECTATIONS['AB_T_100_W_50_50'].each do |test|
      assert_equal(
        vwo_instance.get_variation_name('T_100_W_50_50_WS', test['user'], { custom_variables: false_custom_variables }),
        nil
      )
    end
  end

  def test_track_with_with_no_custom_variables_fails
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_100_W_50_50_WS']), { log_level: Logger::DEBUG })
    USER_EXPECTATIONS['AB_T_100_W_50_50'].each do |test|
      assert_equal(vwo_instance.track('T_100_W_50_50_WS', test['user'], 'ddd'), false)
    end
  end

  def test_track_revenue_value_and_custom_variables_passed_in_args
    arguments_to_track =  {
      'campaign_key' => 'TEST_TRACK',
      'user_id' => 'user_id',
      'goal_identifier' => 'GOAL_ID',
      'revenue_value' => 100,
      'custom_variables' => {
        'a' => 'b'
      }
    }
    assert_equal(
      mock_track(
        arguments_to_track['campaign_key'],
        arguments_to_track['user_id'],
        arguments_to_track['goal_identifier'],
        arguments_to_track['revenue_value'],
        arguments_to_track['custom_variables']),
      arguments_to_track
    )
  end

  def test_track_revenue_value_and_custom_variables_passed_in_args_as_hash
  
    arguments_to_track = {
      'campaign_key' => 'TEST_TRACK',
      'user_id' => 'user_id',
      'goal_identifier' => 'GOAL_ID',
      'revenue_value' => 100,
      'custom_variables' => {
        'a' => 'b'
      }
    }
    assert_equal(
      mock_track(
        arguments_to_track['campaign_key'],
        arguments_to_track['user_id'],
        arguments_to_track['goal_identifier'],
        {
          revenue_value: arguments_to_track['revenue_value'],
          custom_variables:arguments_to_track['custom_variables']
        }),
      arguments_to_track
    )
  end

  def test_track_with_presegmentation_true
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_50_W_50_50_WS']), { log_level: Logger::DEBUG })
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(vwo_instance.track('T_50_W_50_50_WS', test['user'], 'ddd', { custom_variables: true_custom_variables}), !test['variation'].nil?)
    end
  end
  
  def test_track_with_presegmentation_false
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_50_W_50_50_WS']), { log_level: Logger::DEBUG })
    false_custom_variables = {
      'a' => 987.12,
      'hello' => 'world_world'
    }
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(vwo_instance.track('T_50_W_50_50_WS', test['user'], 'ddd', { custom_variables: false_custom_variables }), false)
    end
  end

  def test_track_with_no_dsl_remains_unaffected
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: Logger::DEBUG })
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(vwo_instance.track('AB_T_50_W_50_50', test['user'], 'CUSTOM', { custom_variables: true_custom_variables }), !test['variation'].nil?)
    end
  end

  def test_track_with_no_custom_variables_fails
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_50_W_50_50_WS']), { log_level: Logger::DEBUG })
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(vwo_instance.track('T_50_W_50_50_WS', test['user'], 'ddd'), false)
    end
  end

  def test_feature_enabled_FT_T_75_W_10_20_30_40_WS_true
    set_up('FT_T_75_W_10_20_30_40_WS')
    is_feature_not_enabled_variations = ['Control']
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FT_T_75_W_10_20_30_40_WS', test['user'], { custom_variables: true_custom_variables }),
        !test['variation'].nil? && !is_feature_not_enabled_variations.include?(test['variation'])
      )
    end
  end

  def test_feature_enabled_FT_T_75_W_10_20_30_40_WS_false
    set_up('FT_T_75_W_10_20_30_40_WS')
    false_custom_variables = {
      'a' => 987.12,
      'hello' => 'world_world'
    }
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      assert_equal(
        @vwo.feature_enabled?('FT_T_75_W_10_20_30_40_WS', test['user'], { custom_variables: false_custom_variables }), false)
    end
  end

  def test_feature_enabled_FT_T_75_W_10_20_30_40_WS_false_custom_variables_in_options
    set_up('FT_T_75_W_10_20_30_40_WS')
    false_custom_variables = {
      'a' => 987.12,
      'hello' => 'world_world'
    }
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      assert_equal(
        @vwo.feature_enabled?('FT_T_75_W_10_20_30_40_WS', test['user'], { custom_variables: false_custom_variables }), false)
    end
  end

  def test_get_feature_variable_value_type_string_from_feature_test_t_75_WS_true_options
    set_up('FT_T_75_W_10_20_30_40_WS')
    string_variable = USER_EXPECTATIONS['STRING_VARIABLE']
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FT_T_75_W_10_20_30_40_WS',
        'STRING_VARIABLE',
        test['user'],
        { custom_variables: true_custom_variables }
      )
      assert_equal(result, string_variable[test['variation']]) if result
    end
  end

  def test_get_feature_variable_value_type_string_from_feature_test_t_75_WS_true
    set_up('FT_T_75_W_10_20_30_40_WS')
    string_variable = USER_EXPECTATIONS['STRING_VARIABLE']
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FT_T_75_W_10_20_30_40_WS',
        'STRING_VARIABLE',
        test['user'],
        { custom_variables: true_custom_variables }
      )
      assert_equal(result, string_variable[test['variation']]) if result
    end
  end

  def test_get_feature_variable_value_type_string_from_feature_test_t_75_WS_false
    set_up('FT_T_75_W_10_20_30_40_WS')
    false_custom_variables = {
      'a' => 987.12,
      'hello' => 'world_world'
    }
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      result = @vwo.get_feature_variable_value(
        'FT_T_75_W_10_20_30_40_WS',
        'STRING_VARIABLE',
        test['user'],
        { custom_variables: false_custom_variables }
      )
      assert_equal(result, nil)
    end
  end

  def test_push_corrupted_settings_file
    set_up('DUMMY_SETTINGS')
    assert_equal(false, @vwo.push("1234", '12435t4', '12343'))
  end

  def test_push_true
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(true, vwo_instance.push('browser', 'chrome', '12345'))
  end

  def test_push_int_value_false
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(false, vwo_instance.push('browser', 1, '12345'))
  end

  def test_push_longer_than_255_value_false
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(false, vwo_instance.push('browser', 'a' * 256, '12345'))
  end

  def test_push_exact_255_value_true
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(true, vwo_instance.push('browser', 'a' * 255, '12345'))
  end

  def test_push_longer_than_255_key_false
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(false, vwo_instance.push('a' * 256, 'browser', '12345'))
  end

  def test_push_exact_255_key_true
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(true, vwo_instance.push('a' * 255, 'browser', '12345'))
  end
  
  def test_vwo_initialized_with_no_logger_no_log_level
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: Logger::DEBUG })
    assert_equal(vwo_instance.logger.level, Logger::DEBUG)
  end

  def test_vwo_initialized_with_logger_as_false
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']))
    assert_equal(vwo_instance.logger.level, Logger::DEBUG)
  end

  def test_vwo_initialized_with_loglevel_as_false
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: false })
    assert_equal(vwo_instance.logger.level, Logger::DEBUG)
  end

  def test_vwo_initialized_with_loglevel_as_anything_bad
    vwo_instance = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: 'bad' })
    assert_equal(vwo_instance.logger.level, Logger::DEBUG)
  end
end

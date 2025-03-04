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

require 'json'
require_relative '../lib/vwo'
require 'logger'
require 'test/unit'
require 'mocha/test_unit'

class Object
  def stub_and_raise(fn_name, raise_error)
    singleton_class.send(:define_method, fn_name.to_s) do
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
    @vwo = VWO.new(888_888, '1234567ad94079aa190bc7c9b7654321', nil, nil, true, JSON.generate(SETTINGS_FILE[config_variant] || {}))
    @campaign_key = config_variant
    begin
      @goal_identifier = SETTINGS_FILE[config_variant]['campaigns'][0]['goals'][0]['identifier']
    rescue StandardError => _e
      @goal_identifier = nil
    end
  end

  def mock_track(campaign_key, user_id, goal_identifier, options = {})
    revenue_value = options['revenue_value'] || options[:revenue_value]
    custom_variables = options['custom_variables'] || options[:custom_variables]

    return unless custom_variables

    {
      'campaign_key' => campaign_key,
      'user_id' => user_id,
      'goal_identifier' => goal_identifier,
      'revenue_value' => revenue_value,
      'custom_variables' => custom_variables
    }
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

  def test_get_variation_against_campaign_traffic_50_and_split_50_50_percent
    set_up('AB_T_50_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_100_and_split_50_50_percent
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_100_and_split_25_25_25_25_with_forced_variaton
    set_up('AB_T_100_W_25_25_25_25')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_100_and_split_20_80_percent
    set_up('AB_T_100_W_20_80')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_20_and_split_10_90_percent
    set_up('AB_T_20_W_10_90')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_100_and_split_0_100_percent
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

  def test_get_variation_name_against_campaign_traffic_75_and_split_10_times_10_percent
    set_up('T_75_W_10_TIMES_10')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  # Test activate
  def test_activate_invalid_params
    set_up
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

  def test_activate_against_campaign_traffic_50_and_split_50_50_percent
    set_up('AB_T_50_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_100_and_split_50_50_percent
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_100_and_split_20_80_percent
    set_up('AB_T_100_W_20_80')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_20_and_split_10_90_percent
    set_up('AB_T_20_W_10_90')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_100_and_split_0_100_percent
    set_up('AB_T_100_W_0_100')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_100_and_split_33_x3
    set_up('AB_T_100_W_33_33_33')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  # Test track
  def test_track_invalid_params
    set_up
    assert_equal(@vwo.track(123, 456, 789), false)
  end

  def test_track_invalid_config
    set_up('EMPTY_SETTINGS_FILE')
    assert_equal(@vwo.track(@user_id, 'somecampaign', 'somegoal'), false)
  end

  def test_track_with_no_campaign_key_found
    set_up('AB_T_50_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track('NO_SUCH_CAMPAIGN_KEY', test['user'], @goal_identifier), nil)
    end
  end

  def test_track_with_no_goal_identifier_found
    set_up('AB_T_50_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], 'NO_SUCH_GOAL_IDENTIFIER'), nil)
    end
  end

  def test_track_wrong_campaign_type_passed
    set_up('FR_T_0_W_100')
    result = @vwo.track('FR_T_0_W_100', 'user', 'some_goal_identifier')
    assert_equal(result, nil)
  end

  def test_track_against_campaign_traffic_50_and_split_50_50_percent
    set_up('AB_T_50_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), { @campaign_key => !test['variation'].nil? })
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_r_int
    # It's goal_type is revenue, so test revenue
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, { revenue_value: 23 }), { @campaign_key => !test['variation'].nil? })
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_r_float
    # It's goal_type is revenue, so test revenue
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, { revenue_value: 23.3 }), { @campaign_key => !test['variation'].nil? })
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_r_str
    # It's goal_type is revenue, so test revenue
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, { revenue_value: '23.3' }), { @campaign_key => !test['variation'].nil? })
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_no_r
    # It's goal_type is revenue, so test revenue
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), { @campaign_key => false })
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_options
    # It's goal_type is revenue, so test revenue
    set_up('AB_T_100_W_50_50')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, { 'revenue_value' => 23 }), { @campaign_key => !test['variation'].nil? })
    end
  end

  def test_track_against_campaign_traffic_100_and_split_20_80_percent
    set_up('AB_T_100_W_20_80')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), { @campaign_key => !test['variation'].nil? })
    end
  end

  def test_track_against_campaign_traffic_20_and_split_10_90_percent
    set_up('AB_T_20_W_10_90')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), { @campaign_key => !test['variation'].nil? })
    end
  end

  def test_track_against_campaign_traffic_100_and_split_0_100_percent
    set_up('AB_T_100_W_0_100')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), { @campaign_key => !test['variation'].nil? })
    end
  end

  def test_track_against_campaign_traffic_100_and_split_33_x3
    set_up('AB_T_100_W_33_33_33')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), { @campaign_key => !test['variation'].nil? })
    end
  end

  def test_track_custom_goal
    set_up('AB_T_100_W_0_100')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, { goal_type_to_track: 'CUSTOM' }), { @campaign_key => !test['variation'].nil? })
    end
  end

  def test_track_for_invalid_goal_type_to_track
    set_up('AB_T_100_W_0_100')
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, { goal_type_to_track: 'fs' }), false)
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

  def test_feature_enabled_fr_w_zero
    set_up('FR_T_0_W_100')
    USER_EXPECTATIONS['T_0_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FR_T_0_W_100', test['user']), !test['variation'].nil?)
    end
  end

  def test_feature_enabled_fr_w25
    set_up('FR_T_25_W_100')
    USER_EXPECTATIONS['T_25_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FR_T_25_W_100', test['user']), !test['variation'].nil?)
    end
  end

  def test_feature_enabled_fr_w50
    set_up('FR_T_50_W_100')
    USER_EXPECTATIONS['T_50_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FR_T_50_W_100', test['user']), !test['variation'].nil?)
    end
  end

  def test_feature_enabled_fr_w75
    set_up('FR_T_75_W_100')
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FR_T_75_W_100', test['user']), !test['variation'].nil?)
    end
  end

  def test_feature_enabled_fr_w100
    set_up('FR_T_100_W_100')
    USER_EXPECTATIONS['T_100_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FR_T_100_W_100', test['user']), !test['variation'].nil?)
    end
  end

  def test_feature_enabled_ft_t_75_w_10_20_30_40_percent
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
  def test_get_feature_variable_value_type_string_from_feature_test_t0
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

  def test_get_feature_variable_value_type_string_from_feature_test_t25
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

  def test_get_feature_variable_value_type_string_from_feature_test_t50
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

  def test_get_feature_variable_value_type_string_from_feature_test_t75
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

  def test_get_feature_variable_value_type_string_from_feature_test_t100
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

  def test_get_feature_variable_value_type_string_from_feature_test_t_100_is_feature_enabled
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
      variation_name = 'Control' if %w[Variation-1 Variation-3].include?(variation_name)
      assert_equal(result, string_variable[variation_name]) if result
    end
  end

  def test_get_feature_variable_wrong_variable_types
    set_up('FR_WRONG_VARIABLE_TYPE')
    tests = [
      ['STRING_TO_INTEGER', 123, 'integer', Integer],
      ['STRING_TO_FLOAT', 123.456, 'double', Float],
      ['BOOLEAN_TO_STRING', 'true', 'string', String],
      ['INTEGER_TO_STRING', '24', 'string', String],
      ['INTEGER_TO_FLOAT', 24.0, 'double', Float],
      ['FLOAT_TO_STRING', '24.24', 'string', String],
      ['FLOAT_TO_INTEGER', 24, 'integer', Integer]
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
    tests = [['WRONG_BOOLEAN', nil, 'boolean', nil]]
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
  # def test_activate_raises_exception
  #   set_up()
  #   @vwo.stub_and_raise(:valid_string?, StandardError)
  #   assert_equal(nil, @vwo.activate('SOME_CAMPAIGN', 'USER'))
  # end

  def test_get_variation_name_raises_exception
    set_up
    @vwo.stub_and_raise(:valid_string?, StandardError)
    assert_equal(nil, @vwo.get_variation_name('SOME_CAMPAIGN', 'USER'))
  end

  def test_track_raises_exception
    set_up
    @vwo.stub_and_raise(:valid_string?, StandardError)
    assert_equal(false, @vwo.track('SOME_CAMPAIGN', 'USER', 'GOAL'))
  end

  def test_feature_enabled_raises_exception
    set_up
    @vwo.stub_and_raise(:valid_string?, StandardError)
    assert_equal(false, @vwo.feature_enabled?('SOME_CAMPAIGN', 'USER'))
  end

  def test_get_feature_variable_raises_exception
    set_up
    @vwo.stub_and_raise(:valid_string?, StandardError)
    assert_equal(nil, @vwo.get_feature_variable_value('SOME_CAMPAIGN', 'VARIABLE_KEY', 'USER_ID'))
  end

  def test_push_raises_exception
    set_up
    @vwo.stub_and_raise(:valid_string?, StandardError)
    assert_equal(false, @vwo.push('SOME_CAMPAIGN', 'VARIABLE_KEY', 'USER_ID'))
  end

  def test_vwo_initialized_with_provided_log_level_debug
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: Logger::DEBUG })
    assert_equal(vwo_instance.logging.level, Logger::DEBUG)
  end

  def test_vwo_initialized_with_provided_log_level_warning
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: Logger::WARN })
    assert_equal(vwo_instance.logging.level, Logger::WARN)
  end

  # test activate with pre-segmentation
  def test_activate_with_no_custom_variables_fails
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_50_W_50_50_WS']), { log_level: Logger::DEBUG })
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(vwo_instance.activate('T_50_W_50_50_WS', test['user']), nil)
    end
  end

  def test_activate_with_no_dsl_remains_unaffected
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: Logger::DEBUG })
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
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_100_W_50_50_WS']), { log_level: Logger::DEBUG })
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
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_100_W_50_50_WS']), { log_level: Logger::DEBUG })
    false_custom_variables = {
      'a' => 987_123,
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
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_100_W_50_50_WS']), { log_level: Logger::DEBUG })
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(
        vwo_instance.get_variation_name('T_50_W_50_50_WS', test['user']),
        nil
      )
    end
  end

  def test_get_variation_name_with_no_dsl_remains_unaffected
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_50_W_50_50_WS']), { log_level: Logger::DEBUG })
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
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_100_W_50_50_WS']), { log_level: Logger::DEBUG })
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
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_100_W_50_50_WS']), { log_level: Logger::DEBUG })
    false_custom_variables = {
      'a' => 987_123,
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
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_100_W_50_50_WS']), { log_level: Logger::DEBUG })
    USER_EXPECTATIONS['AB_T_100_W_50_50'].each do |test|
      assert_equal(vwo_instance.track('T_100_W_50_50_WS', test['user'], 'ddd'), { 'T_100_W_50_50_WS' => false })
    end
  end

  def test_track_revenue_value_and_custom_variables_passed_in_args
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
          'revenue_value' => arguments_to_track['revenue_value'],
          'custom_variables' => arguments_to_track['custom_variables']
        }
      ),
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
          'revenue_value' => arguments_to_track['revenue_value'],
          'custom_variables' => arguments_to_track['custom_variables']
        }
      ),
      arguments_to_track
    )
  end

  def test_track_with_presegmentation_true
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_50_W_50_50_WS']), { log_level: Logger::DEBUG })
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(vwo_instance.track('T_50_W_50_50_WS', test['user'], 'ddd', { custom_variables: true_custom_variables }), { 'T_50_W_50_50_WS' => !test['variation'].nil? })
    end
  end

  def test_track_with_presegmentation_false
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_50_W_50_50_WS']), { log_level: Logger::DEBUG })
    false_custom_variables = {
      'a' => 987.12,
      'hello' => 'world_world'
    }
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(vwo_instance.track('T_50_W_50_50_WS', test['user'], 'ddd', { custom_variables: false_custom_variables }), { 'T_50_W_50_50_WS' => false })
    end
  end

  def test_track_with_no_dsl_remains_unaffected
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: Logger::DEBUG })
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(vwo_instance.track('AB_T_50_W_50_50', test['user'], 'CUSTOM', { custom_variables: true_custom_variables }), { 'AB_T_50_W_50_50' => !test['variation'].nil? })
    end
  end

  def test_track_with_no_custom_variables_fails
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['T_50_W_50_50_WS']), { log_level: Logger::DEBUG })
    USER_EXPECTATIONS['AB_T_50_W_50_50'].each do |test|
      assert_equal(vwo_instance.track('T_50_W_50_50_WS', test['user'], 'ddd'), { 'T_50_W_50_50_WS' => false })
    end
  end

  def test_feature_enabled_ft_t_75_w_10_20_30_40_ws_true
    set_up('FT_T_75_W_10_20_30_40_WS')
    is_feature_not_enabled_variations = ['Control']
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FT_T_75_W_10_20_30_40_WS', test['user'], { custom_variables: true_custom_variables }),
                   !test['variation'].nil? && !is_feature_not_enabled_variations.include?(test['variation']))
    end
  end

  def test_feature_enabled_ft_t_75_w_10_20_30_40_ws_false
    set_up('FT_T_75_W_10_20_30_40_WS')
    false_custom_variables = {
      'a' => 987.12,
      'hello' => 'world_world'
    }
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      assert_equal(
        @vwo.feature_enabled?('FT_T_75_W_10_20_30_40_WS', test['user'], { custom_variables: false_custom_variables }), false
      )
    end
  end

  def test_feature_enabled_ft_t_75_w_10_20_30_40_ws_false_custom_variables_in_options
    set_up('FT_T_75_W_10_20_30_40_WS')
    false_custom_variables = {
      'a' => 987.12,
      'hello' => 'world_world'
    }
    USER_EXPECTATIONS['T_75_W_10_20_30_40'].each do |test|
      assert_equal(
        @vwo.feature_enabled?('FT_T_75_W_10_20_30_40_WS', test['user'], { custom_variables: false_custom_variables }), false
      )
    end
  end

  def test_get_feature_variable_value_type_string_from_feature_test_t_75_ws_true_options
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

  def test_get_feature_variable_value_type_string_from_feature_test_t_75_ws_true
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

  def test_get_feature_variable_value_type_string_from_feature_test_t_75_ws_false
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
    assert_equal({}, @vwo.push('1234', '12435t4', '12343'))
  end

  def test_push_true
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(true, vwo_instance.push('browser', 'chrome', '12345')[:browser])
  end

  def test_push_int_value_false
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(false, vwo_instance.push('browser', 1, '12345')[:browser])
  end

  def test_push_longer_than_255_value_false
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(false, vwo_instance.push('browser', 'a' * 256, '12345')[:browser])
  end

  def test_push_exact_255_value_true
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(true, vwo_instance.push('browser', 'a' * 255, '12345')[:browser])
  end

  def test_push_longer_than_255_key_false
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(false, vwo_instance.push('a' * 256, 'browser', '12345')[('a' * 256).to_sym])
  end

  def test_push_exact_255_key_true
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(true, vwo_instance.push('a' * 255, 'browser', '12345')[('a' * 255).to_sym])
  end

  def test_push_for_multiple_custom_dimension
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    custom_dimension_map = { 'browser' => 'chrome', 'key' => 'value' }
    result = vwo_instance.push(custom_dimension_map, '12345')
    result.each do |_tag_key, tag_value|
      assert_equal(true, tag_value)
    end
  end

  def test_push_for_some_invalid_multiple_custom_dimension
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    custom_dimension_map = { 'browser' => 'chrome', 'number' => 1243, 'a' * 256 => 'hello', 'hi' => 'a' * 256 }
    expected = { 'browser' => true, 'number' => false, 'a' * 256 => false, 'hi' => false }

    result = vwo_instance.push(custom_dimension_map, '12345')
    expected.each do |tag_key, tag_value|
      assert_equal(tag_value, result[tag_key.to_sym])
    end
  end

  def test_vwo_initialized_with_no_logger_no_log_level
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: Logger::DEBUG })
    assert_equal(vwo_instance.logging.level, Logger::DEBUG)
  end

  def test_vwo_initialized_with_logger_as_false
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']))
    assert_equal(vwo_instance.logging.level, Logger::DEBUG)
  end

  def test_vwo_initialized_with_loglevel_as_false
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: false })
    assert_equal(vwo_instance.logging.level, Logger::DEBUG)
  end

  def test_vwo_initialized_with_loglevel_as_anything_bad
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), { log_level: 'bad' })
    assert_equal(vwo_instance.logging.level, Logger::DEBUG)
  end

  def test_update_settings_file_for_invalid_sdk_key
    vwo_instance = VWO.new(88_888_888, 1, nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']))
    latest_settings = vwo_instance.get_and_update_settings_file
    assert_equal({}, latest_settings)
  end

  def test_update_settings_file
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']))
    old_settings = vwo_instance.get_settings
    manager = mock
    manager.stubs(:get_settings_file).with(true).returns(JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']))
    vwo_instance.settings_file_manager = manager
    latest_settings = vwo_instance.get_and_update_settings_file
    assert_not_equal(old_settings, latest_settings.to_json)

    old_settings = vwo_instance.get_settings
    manager = mock
    manager.stubs(:get_settings_file).with(true).returns(JSON.generate(old_settings))
    vwo_instance.settings_file_manager = manager
    latest_settings = vwo_instance.get_and_update_settings_file
    assert_equal(old_settings, latest_settings)
  end

  def test_track_for_already_track_user
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']))
    vwo_instance.stubs(:is_eligible_to_send_impression).returns(false)
    variation_data = {}
    variation_data['id'] = 2
    variation_data['name'] = 'variation-1'
    variation_data['goal_identifier'] = '_vwo_CUSTOM'
    variation_decider = mock
    variation_decider.stubs(:get_variation).returns(variation_data)
    vwo_instance.variation_decider = variation_decider
    assert_equal(vwo_instance.track('AB_T_50_W_50_50', 'Ashley', 'CUSTOM'), { 'AB_T_50_W_50_50' => false })
  end

  def test_feature_enabled_for_already_track_user
    vwo_instance = VWO.new(123_456, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['FT_T_75_W_10_20_30_40']))
    vwo_instance.stubs(:is_eligible_to_send_impression).returns(false)
    assert_equal(vwo_instance.feature_enabled?('FT_T_75_W_10_20_30_40', 'Ashley'), true)
  end

  def flush_callback(message, events); end

  def get_batch_events_option
    {
      batch_events: {
        events_per_request: 3,
        request_time_interval: 5,
        flushCallback: method(:flush_callback)
      }
    }
  end

  def initialize_vwo_with_batch_events_option(camp_key, option)
    VWO.new(88_888_888, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE[camp_key]), option)
  end

  # activate, track, feature_enabled? api when vwo object initialized with batch_events options
  def test_api_with_batch_events
    vwo_instance = initialize_vwo_with_batch_events_option('AB_T_50_W_50_50', get_batch_events_option)
    assert_equal(vwo_instance.activate('AB_T_50_W_50_50', 'Ashley', {}), 'Variation-1')
    assert_equal(vwo_instance.activate('AB_T_50_W_50_50', 'Ashley', {}), 'Variation-1')
    assert_equal(vwo_instance.track('AB_T_50_W_50_50', 'Ashley', 'CUSTOM', {})['AB_T_50_W_50_50'], true)
    vwo_instance = initialize_vwo_with_batch_events_option('FT_T_100_W_10_20_30_40', get_batch_events_option)
    assert_equal(vwo_instance.feature_enabled?('FT_T_100_W_10_20_30_40', 'Ashley', {}), true)
  end

  # push api when vwo object initialized with batch_events options
  def test_push_true_for_batch_events
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), get_batch_events_option)
    assert_equal(true, vwo_instance.push('browser', 'chrome', '12345')[:browser])
  end

  def test_without_events_per_request
    options = {
      'batch_events' => {
        'request_time_interval' => 5,
        'flushCallback' => method(:flush_callback)
      }
    }
    vwo_instance = initialize_vwo_with_batch_events_option('AB_T_50_W_50_50', options)
    assert_equal(vwo_instance.activate('AB_T_50_W_50_50', 'Ashley', {}), 'Variation-1')
  end

  def test_without_request_time_interval
    options = {
      batch_events: {
        events_per_request: 3,
        flushCallback: method(:flush_callback)
      }
    }
    vwo_instance = initialize_vwo_with_batch_events_option('AB_T_50_W_50_50', options)
    assert_equal(vwo_instance.activate('AB_T_50_W_50_50', 'Ashley', {}), 'Variation-1')
  end

  def test_without_flush_callback
    options = {
      batch_events: {
        events_per_request: 3,
        request_time_interval: 5
      }
    }
    vwo_instance = initialize_vwo_with_batch_events_option('AB_T_50_W_50_50', options)
    assert_equal(vwo_instance.activate('AB_T_50_W_50_50', 'Ashley', {}), 'Variation-1')
  end

  def test_flush_events
    options = {
      batch_events: {
        events_per_request: 3,
        request_time_interval: 5
      }
    }
    vwo_instance = initialize_vwo_with_batch_events_option('AB_T_50_W_50_50', options)
    assert_equal(vwo_instance.flush_events, true)
  end

  def test_flush_events_with_corrupted_vwo_instance
    set_up('EMPTY_SETTINGS_FILE')
    assert_equal(@vwo.flush_events, false)
  end

  def test_flush_events_raises_exception
    set_up
    @vwo.stub_and_raise(:valid_string?, StandardError)
    assert_equal(@vwo.flush_events, false)
  end

  def integrations_callback(properties); end

  def test_activate_for_hooks
    options = {
      integrations: {
        callback: method(:integrations_callback)
      }
    }
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), options)
    assert_equal(vwo_instance.activate('AB_T_50_W_50_50', 'Ashley', {}), 'Variation-1')
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['FT_T_75_W_10_20_30_40']), options)
    assert_equal(vwo_instance.feature_enabled?('FT_T_75_W_10_20_30_40', 'Ashley', {}), true)
  end

  def test_additional_data_during_vwo_instantiation
    options = {
      log_level: Logger::DEBUG,
      integrations: {
        callback: method(:integrations_callback)
      }
    }
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', VWO::Logger.get_instance, VWO::UserStorage.new, false, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), options)
    additional_data = vwo_instance.usage_stats.usage_stats
    assert_equal(1, additional_data[:ig])
    assert_equal(1, additional_data[:cl])
    assert_equal(1, additional_data[:ss])
    assert_equal(1, additional_data[:ll])
    assert_equal(nil, additional_data[:eb])
    assert_equal(1, additional_data[:_l])
  end

  def test_additional_data_during_vwo_instantiation_for_non_symbol_hash
    options = {
      'batch_events' => {
        'events_per_request' => 3,
        'request_time_interval' => 5,
        'flushCallback' => method(:flush_callback)
      },
      "log_level": Logger::DEBUG,
      'integrations' => {
        'callback' => method(:integrations_callback)
      }
    }
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', VWO::Logger.get_instance, VWO::UserStorage.new, false, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), options)
    additional_data = vwo_instance.usage_stats.usage_stats
    assert_equal(1, additional_data[:ig])
    assert_equal(1, additional_data[:cl])
    assert_equal(1, additional_data[:ss])
    assert_equal(1, additional_data[:ll])
    assert_equal(1, additional_data[:eb])
    assert_equal(1, additional_data[:_l])
  end

  def test_additional_data_for_logging_and_integrations
    options = {
      log_level: Logger::DEBUG,
      integrations: {
        callback: method(:integrations_callback)
      }
    }
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', VWO::Logger.get_instance, nil, false, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), options)
    additional_data = vwo_instance.usage_stats.usage_stats
    assert_equal(1, additional_data[:ig])
    assert_equal(1, additional_data[:cl])
    assert_equal(nil, additional_data[:ss])
    assert_equal(1, additional_data[:ll])
    assert_equal(nil, additional_data[:eb])
    assert_equal(1, additional_data[:_l])
  end

  def test_additional_data_for_user_storage
    options = {}
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', nil, VWO::UserStorage.new, false, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), options)
    additional_data = vwo_instance.usage_stats.usage_stats
    assert_equal(nil, additional_data[:ig])
    assert_equal(nil, additional_data[:cl])
    assert_equal(1, additional_data[:ss])
    assert_equal(nil, additional_data[:ll])
    assert_equal(nil, additional_data[:eb])
    assert_equal(1, additional_data[:_l])
  end

  def test_additional_data_for_logging
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', VWO::Logger.get_instance, nil, false, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']))
    additional_data = vwo_instance.usage_stats.usage_stats
    assert_equal(nil, additional_data[:ig])
    assert_equal(1, additional_data[:cl])
    assert_equal(nil, additional_data[:ss])
    assert_equal(nil, additional_data[:ll])
    assert_equal(nil, additional_data[:eb])
    assert_equal(1, additional_data[:_l])
  end

  def test_additional_data_for_event_batching
    options = {
      batch_events: {
        events_per_request: 3,
        flushCallback: method(:flush_callback)
      }
    }
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', nil, nil, false, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), options)
    additional_data = vwo_instance.usage_stats.usage_stats
    assert_equal(nil, additional_data[:ig])
    assert_equal(nil, additional_data[:cl])
    assert_equal(nil, additional_data[:ss])
    assert_equal(nil, additional_data[:ll])
    assert_equal(1, additional_data[:eb])
    assert_equal(1, additional_data[:_l])
  end

  def initialize_vwo_with_custom_goal_type_to_track(goal_type)
    VWO.new(88_888_888, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_100_W_50_50']), { goal_type_to_track: goal_type })
  end

  def test_track_with_custom_goal_type_to_track
    vwo_instance = initialize_vwo_with_custom_goal_type_to_track('CUSTOM')
    assert_equal(vwo_instance.track('AB_T_100_W_50_50', 'Ashley', 'CUSTOM', {}), { 'AB_T_100_W_50_50' => true })
  end

  def test_track_with_wrong_goal_type_to_track
    vwo_instance = initialize_vwo_with_custom_goal_type_to_track('WRONG_GOAL_TYPE')
    assert_equal(vwo_instance.track('AB_T_100_W_50_50', 'Ashley', 'CUSTOM', {}), false)
  end

  def test_track_with_revenue_goal_type_to_track
    vwo_instance = initialize_vwo_with_custom_goal_type_to_track('REVENUE')
    assert_equal(vwo_instance.track('AB_T_100_W_50_50', 'Ashley', 'abcd', { revenue_value: 10 }), { 'AB_T_100_W_50_50' => true })
  end

  def test_track_with_wrong_campaign_key_type
    vwo_instance = initialize_vwo_with_custom_goal_type_to_track('REVENUE')
    assert_equal(vwo_instance.track(1, 'Ashley', 'REVENUE_TRACKING', { revenue_value: 10 }), false)
  end

  def test_track_with_campaign_keys_array
    vwo_instance = initialize_vwo_with_custom_goal_type_to_track('CUSTOM')
    assert_equal(vwo_instance.track(['AB_T_100_W_50_50'], 'Ashley', 'CUSTOM'), { 'AB_T_100_W_50_50' => true })
  end

  def test_track_with_campaign_keys_nil
    vwo_instance = initialize_vwo_with_custom_goal_type_to_track('CUSTOM')
    assert_equal(vwo_instance.track(nil, 'Ashley', 'CUSTOM'), { 'AB_T_100_W_50_50' => true })
  end

  def test_validate_variables_without_json_variable
    set_up('FR_T_50_W_100')
    assert_equal(@vwo.is_instance_valid, true)
    json_variable = @vwo.get_feature_variable_value('FR_T_50_W_100_WITH_INVALID_JSON_VARIABLE', 'JSON_VARIABLE', 'Ashley', {})
    assert_equal(json_variable, nil)
  end

  def test_validate_variables_with_complete_data
    set_up('FR_T_50_W_100_WITH_JSON_VARIABLE')
    assert_equal(@vwo.is_instance_valid, true)
    json_variable = @vwo.get_feature_variable_value('FR_T_50_W_100_WITH_JSON_VARIABLE', 'JSON_VARIABLE', 'Ashley', {})
    assert_equal(json_variable, { 'data' => 123 })
  end

  def test_validate_variables_with_wrong_json_variable
    set_up('FR_T_50_W_100_WITH_INVALID_JSON_VARIABLE')
    assert_equal(@vwo.is_instance_valid, true)
    json_variable = @vwo.get_feature_variable_value('FR_T_50_W_100_WITH_INVALID_JSON_VARIABLE', 'JSON_VARIABLE', 'Ashley', {})
    assert_equal(json_variable, nil)
  end

  def test_get_feature_variable_value_fail_prior_campaign_activation_for_feature_rollout
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', VWO::Logger.get_instance, VWO::UserStorage.new, false, JSON.generate(SETTINGS_FILE['FR_T_50_W_100']), {})
    string_variable = vwo_instance.get_feature_variable_value('FR_T_50_W_100', 'STRING_VARIABLE', 'Ashley', {})
    assert_equal(string_variable, nil)
  end

  def test_get_feature_variable_value_pass_after_campaign_activation_for_feature_rollout
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', VWO::Logger.get_instance, VWO::UserStorage.new, false, JSON.generate(SETTINGS_FILE['FR_T_50_W_100']), {})
    variation_data = {}
    variation_data['id'] = 1
    variation_data['name'] = 'website'
    variation_decider = mock
    variation_decider.stubs(:get_variation).returns(variation_data)
    vwo_instance.variation_decider = variation_decider
    string_variable = vwo_instance.get_feature_variable_value('FR_T_50_W_100', 'STRING_VARIABLE', 'Ashley', { log_level: Logger::DEBUG })
    assert_equal(string_variable, 'this_is_a_string')
  end

  def test_apis_with_hash_version1
    set_up('T_50_W_50_50_WS')
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    goal_identifier = 'ddd'
    options = { 'custom_variables' => true_custom_variables }
    assert_equal(@vwo.activate('T_50_W_50_50_WS', 'Ashley', options), 'Variation-1')
    assert_equal(@vwo.get_variation_name('T_50_W_50_50_WS', 'Ashley', options), 'Variation-1')
    assert_equal(@vwo.track('T_50_W_50_50_WS', 'Ashley', goal_identifier, options), { 'T_50_W_50_50_WS' => true })

    set_up('FT_T_75_W_10_20_30_40_WS')
    assert_equal(@vwo.feature_enabled?('FT_T_75_W_10_20_30_40_WS', 'Ashley', options), true)
    result = @vwo.get_feature_variable_value('FT_T_75_W_10_20_30_40_WS', 'STRING_VARIABLE', 'Ashley', options)
    assert_equal(result, 'Variation-3 string') if result
    assert_equal(@vwo.get_variation_name('FT_T_75_W_10_20_30_40_WS', 'Ashley', options), 'Variation-3')
  end

  def test_apis_with_hash_version_1and2
    set_up('T_50_W_50_50_WS')
    true_custom_variables = {
      a: 987.1234,
      hello: 'world'
    }
    goal_identifier = 'ddd'
    options = { 'custom_variables' => true_custom_variables }
    assert_equal(@vwo.activate('T_50_W_50_50_WS', 'Ashley', options), 'Variation-1')
    assert_equal(@vwo.get_variation_name('T_50_W_50_50_WS', 'Ashley', options), 'Variation-1')
    assert_equal(@vwo.track('T_50_W_50_50_WS', 'Ashley', goal_identifier, options), { 'T_50_W_50_50_WS' => true })

    set_up('FT_T_75_W_10_20_30_40_WS')
    assert_equal(@vwo.feature_enabled?('FT_T_75_W_10_20_30_40_WS', 'Ashley', options), true)
    result = @vwo.get_feature_variable_value('FT_T_75_W_10_20_30_40_WS', 'STRING_VARIABLE', 'Ashley', options)
    assert_equal(result, 'Variation-3 string') if result
    assert_equal(@vwo.get_variation_name('FT_T_75_W_10_20_30_40_WS', 'Ashley', options), 'Variation-3')
  end

  def test_apis_with_hash_version2
    set_up('T_50_W_50_50_WS')
    true_custom_variables = {
      'a' => 987.1234,
      'hello' => 'world'
    }
    goal_identifier = 'ddd'
    options = { custom_variables: true_custom_variables }
    assert_equal(@vwo.activate('T_50_W_50_50_WS', 'Ashley', options), 'Variation-1')
    assert_equal(@vwo.get_variation_name('T_50_W_50_50_WS', 'Ashley', options), 'Variation-1')
    assert_equal(@vwo.track('T_50_W_50_50_WS', 'Ashley', goal_identifier, options), { 'T_50_W_50_50_WS' => true })

    set_up('FT_T_75_W_10_20_30_40_WS')
    assert_equal(@vwo.feature_enabled?('FT_T_75_W_10_20_30_40_WS', 'Ashley', options), true)
    result = @vwo.get_feature_variable_value('FT_T_75_W_10_20_30_40_WS', 'STRING_VARIABLE', 'Ashley', options)
    assert_equal(result, 'Variation-3 string') if result
    assert_equal(@vwo.get_variation_name('FT_T_75_W_10_20_30_40_WS', 'Ashley', options), 'Variation-3')
  end

  def test_apis_with_hash_version_2and2
    set_up('T_50_W_50_50_WS')
    true_custom_variables = {
      a: 987.1234,
      hello: 'world'
    }
    goal_identifier = 'ddd'
    options = { custom_variables: true_custom_variables }
    assert_equal(@vwo.activate('T_50_W_50_50_WS', 'Ashley', options), 'Variation-1')
    assert_equal(@vwo.get_variation_name('T_50_W_50_50_WS', 'Ashley', options), 'Variation-1')
    assert_equal(@vwo.track('T_50_W_50_50_WS', 'Ashley', goal_identifier, options), { 'T_50_W_50_50_WS' => true })

    set_up('FT_T_75_W_10_20_30_40_WS')
    assert_equal(@vwo.feature_enabled?('FT_T_75_W_10_20_30_40_WS', 'Ashley', options), true)
    result = @vwo.get_feature_variable_value('FT_T_75_W_10_20_30_40_WS', 'STRING_VARIABLE', 'Ashley', options)
    assert_equal(result, 'Variation-3 string') if result
    assert_equal(@vwo.get_variation_name('FT_T_75_W_10_20_30_40_WS', 'Ashley', options), 'Variation-3')
  end

  def test_vwo_instantiation_with_string_type_hash
    options = {
      'log_level' => Logger::DEBUG,
      'integrations' => {
        'callback' => method(:integrations_callback)
      }
    }
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), options)
    assert_equal(vwo_instance.activate('AB_T_50_W_50_50', 'Ashley', {}), 'Variation-1')
    assert_equal(vwo_instance.track('AB_T_50_W_50_50', 'Ashley', 'CUSTOM')['AB_T_50_W_50_50'], true)
  end

  def test_vwo_instantiation_with_symbolize_hash
    options = {
      log_level: Logger::DEBUG,
      integrations: {
        callback: method(:integrations_callback)
      }
    }
    vwo_instance = VWO.new(88_888_888, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_50_W_50_50']), options)
    assert_equal(vwo_instance.activate('AB_T_50_W_50_50', 'Ashley', {}), 'Variation-1')
    assert_equal(vwo_instance.track('AB_T_50_W_50_50', 'Ashley', 'CUSTOM')['AB_T_50_W_50_50'], true)
  end

  def test_fr_whitelisting
    campaign_key = 'FR_T_100_W_100_WHITELISTING'
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['FR_T_100_W_100_WHITELISTING']))
    options = {
      variation_targeting_variables: {
        'chrome' => 'false'
      }
    }

    boolean_variable = USER_EXPECTATIONS['ROLLOUT_VARIABLES']['BOOLEAN_VARIABLE']
    USER_EXPECTATIONS[campaign_key].each do |test|
      is_feature_enabled = vwo_instance.feature_enabled?(campaign_key, test['user'], options)
      assert_equal(is_feature_enabled, true)
      result = vwo_instance.get_feature_variable_value(campaign_key, 'BOOLEAN_VARIABLE', test['user'], options)
      assert_equal(result, boolean_variable)
    end
  end

  def test_fr_whitelisting_passed_when_traffic_zero
    campaign_key = 'FR_T_100_W_100_WHITELISTING'
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['FR_T_100_W_100_WHITELISTING']))
    vwo_instance.get_settings['campaigns'][0]['percentTraffic'] = 0
    options = {
      variation_targeting_variables: {
        'chrome' => 'false'
      }
    }

    boolean_variable = USER_EXPECTATIONS['ROLLOUT_VARIABLES']['BOOLEAN_VARIABLE']
    USER_EXPECTATIONS[campaign_key].each do |test|
      is_feature_enabled = vwo_instance.feature_enabled?(campaign_key, test['user'], options)
      assert_equal(is_feature_enabled, true)
      result = vwo_instance.get_feature_variable_value(campaign_key, 'BOOLEAN_VARIABLE', test['user'], options)
      assert_equal(result, boolean_variable)
    end
  end

  def test_fr_whitelisting_not_passed
    campaign_key = 'FR_T_100_W_100_WHITELISTING'
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['FR_T_100_W_100_WHITELISTING']))
    options = {
      variation_targeting_variables: {
        'chrome' => 'true'
      }
    }

    boolean_variable = USER_EXPECTATIONS['ROLLOUT_VARIABLES']['BOOLEAN_VARIABLE']
    USER_EXPECTATIONS[campaign_key].each do |test|
      is_feature_enabled = vwo_instance.feature_enabled?(campaign_key, test['user'], options)
      assert_equal(is_feature_enabled, true)
      result = vwo_instance.get_feature_variable_value(campaign_key, 'BOOLEAN_VARIABLE', test['user'], options)
      assert_equal(result, boolean_variable)
    end
  end

  def test_fr_whitelisting_not_passed_and_traffic10
    campaign_key = 'FR_T_100_W_100_WHITELISTING'
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['FR_T_100_W_100_WHITELISTING']))
    vwo_instance.get_settings['campaigns'][0]['percentTraffic'] = 10
    options = {
      variation_targeting_variables: {
        'chrome' => 'true'
      }
    }

    USER_EXPECTATIONS['FR_T_10_W_100_WHITELISTING_FAIL'].each do |test|
      is_feature_enabled = vwo_instance.feature_enabled?(campaign_key, test['user'], options)
      assert_equal(is_feature_enabled, test['is_feature_enabled'])
      result = vwo_instance.get_feature_variable_value(campaign_key, 'BOOLEAN_VARIABLE', test['user'], options)
      assert_equal(result, test['boolean_variable_value'])
    end
  end

  def test_activate_with_event_arch
    set_up('AB_T_100_W_50_50')
    @vwo.get_settings['isEventArchEnabled'] = true
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_feature_enabled_with_event_arch
    set_up('FR_T_100_W_100')
    @vwo.get_settings['isEventArchEnabled'] = true

    USER_EXPECTATIONS['T_100_W_10_20_30_40'].each do |test|
      assert_equal(@vwo.feature_enabled?('FR_T_100_W_100', test['user']), !test['variation'].nil?)
    end
  end

  def test_track_with_event_arch
    set_up('AB_T_100_W_50_50')
    @vwo.get_settings['isEventArchEnabled'] = true
    @vwo.get_settings['campaigns'][0]['goals'][0]['revenueProp'] = 'dummyRevenueProperty'
    USER_EXPECTATIONS[@campaign_key].each do |test|
      result = @vwo.track(@campaign_key, test['user'], @goal_identifier, { revenue_value: '23.3' })
      assert_equal(result, { @campaign_key => !test['variation'].nil? })
    end
  end

  def test_push_true_with_event_arch
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    vwo_instance.get_settings['isEventArchEnabled'] = true
    assert_equal(true, vwo_instance.push('browser', 'chrome', '12345')[:browser])
  end

  def test_push_int_value_false_with_event_arch
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    vwo_instance.get_settings['isEventArchEnabled'] = true
    assert_equal(false, vwo_instance.push('browser', 1, '12345')[:browser])
  end

  def test_push_true_with_two_arg_and_with_event_arch
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    vwo_instance.get_settings['isEventArchEnabled'] = true
    assert_equal(true, vwo_instance.push({ 'browser' => 'chrome' }, '12345')[:browser])
  end

  def test_push_true_with_two_arg
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(true, vwo_instance.push({ 'browser' => 'chrome' }, '12345')[:browser])
  end

  def test_push_int_value_false_with_two_arg_and_with_event_arch
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    vwo_instance.get_settings['isEventArchEnabled'] = true
    assert_equal(false, vwo_instance.push({ 'browser' => 1 }, '12345')[:browser])
  end

  def test_push_int_value_false_with_two_arg
    vwo_instance = VWO.new(60_781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE['DUMMY_SETTINGS_FILE']), { log_level: Logger::DEBUG })
    assert_equal(false, vwo_instance.push({ 'browser' => 1 }, '12345')[:browser])
  end

  def test_get_variation_as_user_hash_passes_whitelisting
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(SETTINGS_FILE['AB_T_100_W_25_25_25_25']))

    vwo_instance.get_settings['campaigns'][0]['isUserListEnabled'] = true
    vwo_instance.get_settings['campaigns'][0]['variations'][1]['segments'] = {
      'or' => [
        'user' => '78A6CEDE959A518491D7DCEDC0A01686'
      ]
    }
    assert_equal(vwo_instance.get_variation_name('AB_T_100_W_25_25_25_25', 'Rohit'), 'Variation-1')
  end

  def test_set_opt_out_api
    set_up('T_50_W_50_50_WS')
    assert_equal(@vwo.set_opt_out, true)
  end

  def test_apis_when_set_opt_out_called
    set_up('T_50_W_50_50_WS')

    assert_equal(@vwo.set_opt_out, true)
    assert_equal(@vwo.activate('T_50_W_50_50_WS', 'Ashley', {}), nil)
    assert_equal(@vwo.get_variation_name('T_50_W_50_50_WS', 'Ashley', {}), nil)
    goal_identifier = 'ddd'
    assert_equal(@vwo.track('T_50_W_50_50_WS', 'Ashley', goal_identifier, {}), false)
    assert_equal(@vwo.feature_enabled?('T_50_W_50_50_WS', 'Ashley', {}), false)
    assert_equal(@vwo.get_feature_variable_value('FT_T_75_W_10_20_30_40_WS', 'STRING_VARIABLE', 'Ashley', {}), nil)
    assert_equal(@vwo.get_and_update_settings_file, false)
    assert_equal(@vwo.push('tagKey', 'tagValue', 'Ashley'), {})
    assert_equal(@vwo.flush_events, false)
  end

  def test_apis_when_set_opt_out_called_with_event_batch
    options = {
      batch_events: {
        events_per_request: 3,
        request_time_interval: 5
      }
    }
    vwo_instance = initialize_vwo_with_batch_events_option('AB_T_50_W_50_50', options)

    assert_equal(vwo_instance.set_opt_out, true)
    assert_equal(vwo_instance.activate('T_50_W_50_50_WS', 'Ashley', {}), nil)
    assert_equal(vwo_instance.get_variation_name('T_50_W_50_50_WS', 'Ashley', {}), nil)
    goal_identifier = 'ddd'
    assert_equal(vwo_instance.track('T_50_W_50_50_WS', 'Ashley', goal_identifier, {}), false)
    assert_equal(vwo_instance.feature_enabled?('T_50_W_50_50_WS', 'Ashley', {}), false)
    assert_equal(vwo_instance.get_feature_variable_value('FT_T_75_W_10_20_30_40_WS', 'STRING_VARIABLE', 'Ashley', {}), nil)
    assert_equal(vwo_instance.get_and_update_settings_file, false)
    assert_equal(vwo_instance.push('tagKey', 'tagValue', 'Ashley'), {})
    assert_equal(vwo_instance.flush_events, false)
  end
end

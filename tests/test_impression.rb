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

require 'json'
require_relative '../lib/vwo'
require_relative '../lib/vwo/utils/impression'
require_relative '../lib/vwo/enums'
require 'test/unit'
require 'mocha/test_unit'

class ImpressionTest < Test::Unit::TestCase
    include VWO::Utils::Impression
    include VWO::Enums
    EVENT_ARCH_QUERY_PARAMS = ['a', 'en', 'eTime', 'random', 'env', 'p']

    def test_build_event_arch_payload_for_visitor
        account_id = 1
        sdk_key = '12345'
        config = {"accountId" => account_id, "sdkKey" => sdk_key}
        query_params = get_events_base_properties(config, EventEnum::VWO_VARIATION_SHOWN)
        properties = get_track_user_payload_data(config, 'Ashley', EventEnum::VWO_VARIATION_SHOWN, 20, 3)

        expected_properties = {
            d: {
                msgId: "string",
                visId: "string",
                sessionId: 123,
                event: {
                    props: {
                        sdkName: "string",
                        sdkVersion: "string",
                        id: 12,
                        isFirst: 1233,
                        variation: 2,
                        '$visitor': {
                            props: {
                                vwo_fs_environment: "string"
                            }
                        },
                    },
                    name: "string",
                    time: 12345
                },
                visitor: {
                    props: {
                        vwo_fs_environment: "string"
                    }
                }
            }
        }

        is_valid = check_all_properties_present(query_params, EVENT_ARCH_QUERY_PARAMS)
        assert_equal(true, is_valid)
        is_valid = check_all_properties_present_and_their_types(properties, expected_properties)
        assert_equal(true, is_valid)
    end

    def test_build_event_arch_payload_for_goal
        account_id = 1
        sdk_key = '12345'
        config = {"accountId" => account_id, "sdkKey" => sdk_key}
        goal_identifier = 'goalIdentifier'
        metric_map = {
            "1": 10,
            "2": 20,
            "5": 30
        }
        dummy_revenue_property = ['dummyRevenueProperty1', 'dummyRevenueProperty2'];
        query_params = get_events_base_properties(config, goal_identifier)
        properties = get_track_goal_payload_data(config, 'Ashley', goal_identifier, 12, metric_map, dummy_revenue_property)

        expected_properties = {
            d: {
                msgId: "string",
                visId: "string",
                sessionId: 123,
                event: {
                    props: {
                        sdkName: "string",
                        sdkVersion: "string",
                        vwoMeta: {
                            metric: {
                                id_1: ["g_10"],
                                id_2: ["g_20"],
                                id_5: ["g_30"]
                            },
                            dummyRevenueProperty1: 12,
                            dummyRevenueProperty2: 12
                        },
                        isCustomEvent: true,
                        '$visitor': {
                            props: {
                                vwo_fs_environment: "string"
                            }
                        },
                    },
                    name: "string",
                    time: 12345
                },
                visitor: {
                    props: {
                        vwo_fs_environment: "string"
                    }
                }
            }
        }

        is_valid = check_all_properties_present(query_params, EVENT_ARCH_QUERY_PARAMS)
        assert_equal(true, is_valid)
        is_valid = check_all_properties_present_and_their_types(properties, expected_properties)
        assert_equal(true, is_valid)
    end

    def test_build_event_arch_payload_for_push
        account_id = 1
        sdk_key = '12345'
        config = {"accountId" => account_id, "sdkKey" => sdk_key}
        query_params = get_events_base_properties(config, EventEnum::VWO_SYNC_VISITOR_PROP)
        properties = get_push_payload_data(config, 'Ashley', EventEnum::VWO_SYNC_VISITOR_PROP, { tagKey1: "tagValue1", tagKey2: 'tagValue2'})

        expected_properties = {
            d: {
                msgId: "string",
                visId: "string",
                sessionId: 123,
                event: {
                    props: {
                        sdkName: "string",
                        sdkVersion: "string",
                        isCustomEvent: true,
                        '$visitor': {
                            props: {
                                vwo_fs_environment: "string",
                                tagKey1: "tagValue1",
                                tagKey2: 'tagValue2'
                            }
                        },
                    },
                    name: "string",
                    time: 12345
                },
                visitor: {
                    props: {
                        vwo_fs_environment: "string",
                        tagKey1: "tagValue1",
                        tagKey2: 'tagValue2'
                    }
                }
            }
        }

        is_valid = check_all_properties_present(query_params, EVENT_ARCH_QUERY_PARAMS)
        assert_equal(true, is_valid)
        is_valid = check_all_properties_present_and_their_types(properties, expected_properties)
        assert_equal(true, is_valid)
    end

    def check_all_properties_present(properties, expected_properties)
        expected_properties.each do |field|
            unless properties.key? (field.to_sym)
                return false
            end
        end
        true
    end

    def check_all_properties_present_and_their_types(properties, expected_properties)
        expected_properties.each do |key, value|
            if !(properties.key? key) || (properties[key]).class != (expected_properties[key]).class
                return false
            elsif (properties[key]).is_a?(Hash)
                is_valid = check_all_properties_present_and_their_types(properties[key], expected_properties[key])
                unless is_valid
                    return false
                end
            end
        end
        true
    end
end

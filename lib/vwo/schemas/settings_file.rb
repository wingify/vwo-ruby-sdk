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

class VWO
  # Schema for verifying the settings_file provided by the customer
  module Schema
    SETTINGS_FILE_SCHEMA = {
      type: 'object',
      properties: {
        version: {
          type: %w[number string]
        },
        accountId: {
          type: %w[number string]
        },
        isEventArchEnabled: {
          type: ['boolean']
        },
        collectionPrefix: {
          type: ['string']
        },
        campaigns: {
          if: {
            type: 'array'
          },
          then: {
            minItems: 1,
            items: {
              '$ref' => '#/definitions/campaign_object_schema'
            }
          },
          else: {
            type: 'object',
            maxProperties: 0
          }
        }
      },
      definitions: {
        campaign_variation_schema: {
          type: 'object',
          properties: {
            id: {
              type: %w[number string]
            },
            name: {
              type: ['string']
            },
            weight: {
              type: %w[number string]
            },
            variables: {
              type: 'array',
              items: {
                '$ref' => '#/definitions/variables_schema'
              }
            }
          },
          required: %w[id name weight]
        },
        campaign_object_schema: {
          type: 'object',
          properties: {
            id: {
              type: %w[number string]
            },
            key: {
              type: ['string']
            },
            name: {
              type: ['string']
            },
            status: {
              type: ['string']
            },
            percentTraffic: {
              type: ['number']
            },
            variations: {
              type: 'array',
              items: {
                '$ref' => '#/definitions/campaign_variation_schema'
              }
            },
            variables: {
              type: 'array',
              items: {
                '$ref' => '#/definitions/variables_schema'
              }
            },
            isBucketingSeedEnabled: ['boolean'],
            isUserListEnabled: ['boolean'],
            isAlwaysCheckSegment: ['boolean'],
            minItems: 2
          }
        },
        variables_schema: {
          type: 'object',
          properties: {
            id: {
              type: %w[number string]
            },
            key: {
              type: ['string']
            },
            type: {
              type: ['string']
            },
            value: {
              type: %w[number string boolean double object]
            }
          },
          required: %w[id key type value]
        },
        required: %w[
          id
          key
          status
          percentTraffic
          variations
        ]
      },
      required: %w[
        version
        accountId
        campaigns
      ]
    }.freeze
  end
end

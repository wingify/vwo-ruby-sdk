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

require 'murmurhash3'
require_relative '../enums'
require_relative '../utils/validations'
require_relative '../utils/log_message'
require_relative '../constants'
require_relative '../utils/get_account_flags'

class VWO
  module Core
    class Bucketer
      include VWO::Enums
      include VWO::CONSTANTS
      include VWO::Utils::Validations

      # Took reference from StackOverflow(https://stackoverflow.com/) to:
      # convert signed to unsigned integer in python from StackOverflow
      # Author - Duncan (https://stackoverflow.com/users/107660/duncan)
      # Source - https://stackoverflow.com/a/20766900/2494535
      U_MAX_32_BIT = 0xFFFFFFFF
      MAX_HASH_VALUE = 2**32
      FILE = FileNameEnum::BUCKETER

      def initialize
        @logger = VWO::Utils::Logger
      end

      # Calculate if this user should become part of the campaign or not
      # @param[String]         :user_id     The unique ID assigned to a user
      # @param[Dict]           :campaign    For getting traffic allotted to the campaign
      # @param[Boolean]        :disable_logs  if true, do not log log-message
      # @return[Boolean]                    If User is a part of Campaign or not

      def user_part_of_campaign?(user_id, campaign, disable_logs = false)
        unless valid_value?(user_id)
          @logger.log(
            LogLevelEnum::ERROR,
            'USER_ID_INVALID',
            {
              '{file}' => FILE,
              '{userId}' => user_id
            }
          )
          return false
        end

        return false if campaign.nil?

        traffic_allocation = campaign['percentTraffic']
        value_assigned_to_user = get_bucket_value_for_user(user_id, campaign, nil, disable_logs)
        is_user_part = (value_assigned_to_user != 0) && value_assigned_to_user <= traffic_allocation
        @logger.log(
          LogLevelEnum::INFO,
          'USER_CAMPAIGN_ELIGIBILITY',
          {
            '{file}' => FILE,
            '{userId}' => user_id,
            '{status}' => is_user_part ? 'eligible' : 'not eligible',
            '{campaignKey}' => campaign['key']
          },
          disable_logs
        )
        is_user_part
      end

      # Validates the User ID and
      # Generates Variation into which the User is bucketed to
      #
      # @param[String]            :user_id          The unique ID assigned to User
      # @param[Hash]              :campaign         The Campaign of which User is a part of
      # @param[Boolean]             :disable_logs   if true, do not log log-message
      #
      # @return[Hash|nil}                           Variation data into which user is bucketed to
      #                                             or nil if not
      def bucket_user_to_variation(user_id, campaign, disable_logs = false)
        unless valid_value?(user_id)
          @logger.log(
            LogLevelEnum::ERROR,
            'USER_ID_INVALID',
            {
              '{file}' => FILE,
              '{userId}' => user_id
            }
          )
          return
        end

        return unless campaign

        isNBv2 = VWO::Utils::GetAccountFlags.get_instance.get_isNbv2_flag
        isNB = VWO::Utils::GetAccountFlags.get_instance.get_isNB_flag
        account_id = VWO::Utils::GetAccountFlags.get_instance.get_account_id

        user_id_for_hash_value = user_id
        multiplier = MAX_TRAFFIC_VALUE.to_f / campaign['percentTraffic'] / 100

        if ((!isNB && !isNBv2) || (isNB && campaign['isOB'])) && campaign['percentTraffic']
          # Old bucketing logic if feature flag is OFF or
          # Feature flag is ON and campaign is old i.e. created before feature flag was turned ON
          user_id_for_hash_value = "#{campaign['id']}_#{user_id}" if campaign['isBucketingSeedEnabled']
          multiplier = MAX_TRAFFIC_VALUE.to_f / campaign['percentTraffic'] / 100
        elsif ((isNB && !campaign['isOB'] && !isNBv2) || (isNBv2 && campaign['isOBv2']))
          # New bucketing logic if feature flag is ON and campaign is new i.e. created after feature flag was turned ON
          user_id_for_hash_value = user_id
          multiplier = 1
        else
          # new bucketing V2 Logic
          user_id_for_hash_value = "#{campaign['id']}_#{account_id}_#{user_id}"
          multiplier = 1
        end

        hash_value = MurmurHash3::V32.str_hash(user_id_for_hash_value, SEED_VALUE) & U_MAX_32_BIT
        bucket_value = get_bucket_value(
          hash_value,
          MAX_TRAFFIC_VALUE,
          multiplier
        )

        @logger.log(
          LogLevelEnum::DEBUG,
          'USER_CAMPAIGN_BUCKET_VALUES',
          {
            '{file}' => FILE,
            '{campaignKey}' => campaign['key'],
            '{userId}' => user_id,
            '{percentTraffic}' => campaign['percentTraffic'],
            '{hashValue}' => hash_value,
            '{bucketValue}' => bucket_value
          },
          disable_logs
        )

        get_variation(campaign['variations'], bucket_value)
      end

      # Returns the Variation by checking the Start and End
      # Bucket Allocations of each Variation
      #
      # @param[Hash]        :campaign       Which contains the variations
      # @param[Integer]     :bucket_value   The bucket Value of the user
      # @return[Hash|nil]                   Variation data allotted to the user or None if not
      #
      def get_variation(variations, bucket_value)
        variations.find do |variation|
          (variation['start_variation_allocation']..variation['end_variation_allocation']).cover?(bucket_value)
        end
      end

      # Validates the User ID and generates Bucket Value of the
      # User by hashing the userId by murmurHash and scaling it down.
      #
      # @param[String]    :user_id    The unique ID assigned to User
      # @param[String]    :campaign   Campaign data
      # @return[Integer]              The bucket Value allotted to User
      #                               (between 1 to $this->$MAX_TRAFFIC_PERCENT)
      def get_bucket_value_for_user(user_id, campaign = {}, group_id = nil, disable_logs = false)
        user_id_for_hash_value = user_id
        if group_id
          user_id_for_hash_value = "#{group_id}_#{user_id}"
        elsif campaign['isBucketingSeedEnabled']
          user_id_for_hash_value = "#{campaign['id']}_#{user_id}"
        end

        isNBv2 = VWO::Utils::GetAccountFlags.get_instance.get_isNbv2_flag
        isNB = VWO::Utils::GetAccountFlags.get_instance.get_isNB_flag

        if isNBv2 || isNB || campaign['isBucketingSeedEnabled']
          user_id_for_hash_value = "#{campaign['id']}_#{user_id}"
        end

        hash_value = MurmurHash3::V32.str_hash(user_id_for_hash_value, SEED_VALUE) & U_MAX_32_BIT
        bucket_value = get_bucket_value(hash_value, MAX_TRAFFIC_PERCENT)

        @logger.log(
          LogLevelEnum::DEBUG,
          'USER_HASH_BUCKET_VALUE',
          {
            '{file}' => FILE,
            '{hashValue}' => hash_value,
            '{userId}' => user_id,
            '{bucketValue}' => bucket_value
          },
          disable_logs
        )
        bucket_value
      end

      # Generates Bucket Value of the User by hashing the User ID by murmurHash
      # And scaling it down.
      #
      # @param[Integer]             :hash_value   HashValue generated after hashing
      # @param[Integer]             :max_value    The value up-to which hashValue needs to be scaled
      # @param[Integer]             :multiplier
      # @return[Integer]                          Bucket Value of the User
      #
      def get_bucket_value(hash_value, max_value, multiplier = 1)
        ratio = hash_value.to_f / MAX_HASH_VALUE
        multiplied_value = (max_value * ratio + 1) * multiplier
        multiplied_value.to_i
      end

      # Returns a campaign by checking the Start and End Bucket Allocations of each campaign.
      #
      # @param[Integer]     :range_for_campaigns       the bucket value of the user
      # @param[Hash]        :campaigns                 The bucket Value of the user
      # @return[Hash|nil]
      #
      def get_campaign_using_range(range_for_campaigns, campaigns)
        range_for_campaigns *= 100
        campaigns.each do |campaign|
          return campaign if campaign['max_range'] && campaign['max_range'] >= range_for_campaigns && campaign['min_range'] <= range_for_campaigns
        end
        nil
      end
    end
  end
end

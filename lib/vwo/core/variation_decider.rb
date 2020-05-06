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

require_relative '../logger'
require_relative '../enums'
require_relative '../utils/campaign'
require_relative '../services/segment_evaluator'
require_relative '../utils/validations'
require_relative 'bucketer'

class VWO
  module Core
    class VariationDecider
      attr_reader :user_storage_service

      include VWO::Enums
      include VWO::Utils::Campaign
      include VWO::Utils::Validations

      FILE = FileNameEnum::VariationDecider

      # Initializes various services
      # @param[Hash] -   Settings file
      # @param[Class] -  Class instance having the capability of
      #                  get and save.
      def initialize(settings_file, user_storage_service = nil)
        @logger = VWO::Logger.get_instance
        @user_storage_service = user_storage_service
        @bucketer = VWO::Core::Bucketer.new
        @settings_file = settings_file
        @segment_evaluator = VWO::Services::SegmentEvaluator.new
      end

      # Returns variation for the user for the passed campaign-key
      # Check if Whitelisting is applicable, evaluate it, if any eligible variation is found,return, otherwise skip it
      # Check in User Storage, if user found, validate variation and return
      # Otherwise, proceed with variation assignment logic
      #
      #
      # @param[String]          :user_id             The unique ID assigned to User
      # @param[Hash]            :campaign            Campaign hash itself
      # @param[String]          :campaign_key        The unique ID of the campaign passed
      # @return[String,String]                       ({variation_id, variation_name}|Nil): Tuple of
      #                                              variation_id and variation_name if variation allotted, else nil

      def get_variation(user_id, campaign, api_name, campaign_key, custom_variables = {}, variation_targeting_variables = {})
        campaign_key ||= campaign['key']

        return unless campaign

        if campaign['isForcedVariationEnabled']
          variation = evaluate_whitelisting(
            user_id,
            campaign,
            api_name,
            campaign_key,
            variation_targeting_variables
          )
          status = if variation
                     StatusEnum::PASSED
                   else
                     StatusEnum::FAILED
                   end

          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::SEGMENTATION_STATUS,
              file: FILE,
              campaign_key: campaign_key,
              user_id: user_id,
              status: status,
              custom_variables: variation_targeting_variables,
              variation_name: status == StatusEnum::PASSED ? "and #{variation['name']} is Assigned" : ' ',
              segmentation_type: SegmentationTypeEnum::WHITELISTING,
              api_name: api_name
            )
          )

          return variation if variation && variation['name']
        else
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::WHITELISTING_SKIPPED,
              file: FILE,
              campaign_key: campaign_key,
              user_id: user_id,
              api_name: api_name
            )
          )
        end

        user_campaign_map = get_user_storage(user_id, campaign_key)
        variation = get_stored_variation(user_id, campaign_key, user_campaign_map) if valid_hash?(user_campaign_map)

        if variation
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::GOT_STORED_VARIATION,
              file: FILE,
              campaign_key: campaign_key,
              user_id: user_id,
              variation_name: variation['name']
            )
          )
          return variation
        end

        # Pre-segmentation

        segments = get_segments(campaign)
        is_valid_segments = valid_value?(segments)

        if is_valid_segments
          unless custom_variables
            @logger.log(
              LogLevelEnum::INFO,
              format(
                LogMessageEnum::InfoMessages::NO_CUSTOM_VARIABLES,
                file: FILE,
                campaign_key: campaign_key,
                user_id: user_id,
                api_name: api_name
              )
            )
            custom_variables = {}
          end
          unless @segment_evaluator.evaluate(campaign_key, user_id, segments, custom_variables)
            @logger.log(
              LogLevelEnum::INFO,
              format(
                LogMessageEnum::InfoMessages::USER_FAILED_SEGMENTATION,
                file: FileNameEnum::SegmentEvaluator,
                user_id: user_id,
                campaign_key: campaign_key,
                custom_variables: custom_variables
              )
            )
            return
          end
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::USER_PASSED_SEGMENTATION,
              file: FileNameEnum::SegmentEvaluator,
              user_id: user_id,
              campaign_key: campaign_key,
              custom_variables: custom_variables
            )
          )
        else
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::SKIPPING_SEGMENTATION,
              file: FILE,
              campaign_key: campaign_key,
              user_id: user_id,
              api_name: api_name,
              variation: ''
            )
          )
        end

        variation = get_variation_allotted(user_id, campaign)

        if variation && variation['name']
          save_user_storage(user_id, campaign_key, variation['name']) if variation['name']

          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::VARIATION_ALLOCATED,
              file: FILE,
              campaign_key: campaign_key,
              user_id: user_id,
              variation_name: variation['name'],
              campaign_type: campaign['type']
            )
          )
        else
          @logger.log(
            LogLevelEnum::INFO,
            format(LogMessageEnum::InfoMessages::NO_VARIATION_ALLOCATED, file: FILE, campaign_key: campaign_key, user_id: user_id)
          )
        end
        variation
      end

      # Returns the Variation Alloted for required campaign
      #
      # @param[String]  :user_id      The unique key assigned to User
      # @param[Hash]    :campaign     Campaign hash for Unique campaign key
      #
      # @return[Hash]

      def get_variation_allotted(user_id, campaign)
        unless valid_value?(user_id)
          @logger.log(
            LogLevelEnum::ERROR,
            format(LogMessageEnum::ErrorMessages::INVALID_USER_ID, file: FILE, user_id: user_id, method: 'get_variation_alloted')
          )
          return
        end

        if @bucketer.user_part_of_campaign?(user_id, campaign)
          variation = get_variation_of_campaign_for_user(user_id, campaign)
          @logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::GOT_VARIATION_FOR_USER,
              file: FILE,
              variation_name: variation['name'],
              user_id: user_id,
              campaign_key: campaign['key'],
              method: 'get_variation_allotted'
            )
          )
          variation
        else
          # not part of campaign
          @logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::USER_NOT_PART_OF_CAMPAIGN,
              file: FILE,
              user_id: user_id,
              campaign_key: nil,
              method: 'get_variation_allotted'
            )
          )
          nil
        end
      end

      # Assigns variation to a particular user depending on the campaign PercentTraffic.
      #
      # @param[String]              :user_id      The unique ID assigned to a user
      # @param[Hash]                :campaign     The Campaign of which user is to be made a part of
      # @return[Hash]                         Variation allotted to User

      def get_variation_of_campaign_for_user(user_id, campaign)
        unless campaign
          @logger.log(
            LogLevelEnum::ERROR,
            format(
              LogMessageEnum::ErrorMessages::INVALID_CAMPAIGN,
              file: FILE,
              method: 'get_variation_of_campaign_for_user'
            )
          )
          return nil
        end

        variation = @bucketer.bucket_user_to_variation(user_id, campaign)

        if variation && variation['name']
          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::GOT_VARIATION_FOR_USER,
              file: FILE,
              variation_name: variation['name'],
              user_id: user_id,
              campaign_key: campaign['key']
            )
          )
          return variation
        end

        @logger.log(
          LogLevelEnum::INFO,
          format(
            LogMessageEnum::InfoMessages::USER_GOT_NO_VARIATION,
            file: FILE,
            user_id: user_id,
            campaign_key: campaign['key']
          )
        )
        nil
      end

      private

      # Evaluate all the variations in the campaign to find
      #
      # @param[String]  :user_id                            The unique key assigned to User
      # @param[Hash]    :campaign                           Campaign hash for Unique campaign key
      # @param[String]  :api_name                           The key Passed to identify the calling API
      # @param[String]  :campaign_key                       Unique campaign key
      # @param[Hash]    :variation_targeting_variables      Key/value pair of Whitelisting Custom Attributes
      #
      # @return[Hash]

      def evaluate_whitelisting(user_id, campaign, api_name, campaign_key, variation_targeting_variables = {})
        if variation_targeting_variables.nil?
          variation_targeting_variables = { '_vwo_user_id' => user_id }
        else
          variation_targeting_variables['_vwo_user_id'] = user_id
        end
        targeted_variations = []

        campaign['variations'].each do |variation|
          segments = get_segments(variation)
          is_valid_segments = valid_value?(segments)
          if is_valid_segments
            if @segment_evaluator.evaluate(campaign_key, user_id, segments, variation_targeting_variables)
              targeted_variations.push(variation)
              status = StatusEnum::PASSED
            else
              status = StatusEnum::FAILED
            end
            @logger.log(
              LogLevelEnum::DEBUG,
              format(
                LogMessageEnum::DebugMessages::SEGMENTATION_STATUS,
                file: FILE,
                campaign_key: campaign_key,
                user_id: user_id,
                status: status,
                custom_variables: variation_targeting_variables,
                variation_name: variation['name'],
                segmentation_type: SegmentationTypeEnum::WHITELISTING,
                api_name: api_name
              )
            )
          else
            @logger.log(
              LogLevelEnum::DEBUG,
              format(
                LogMessageEnum::InfoMessages::SKIPPING_SEGMENTATION,
                file: FILE,
                campaign_key: campaign_key,
                user_id: user_id,
                api_name: api_name,
                variation: variation['name']
              )
            )
          end
        end

        if targeted_variations.length > 1
          targeted_variations_deep_clone = Marshal.load(Marshal.dump(targeted_variations))
          scale_variation_weights(targeted_variations_deep_clone)
          current_allocation = 0
          targeted_variations_deep_clone.each do |variation|
            step_factor = get_variation_bucketing_range(variation['weight'])
            if step_factor > 0
              start_range = current_allocation + 1
              end_range = current_allocation + step_factor
              variation['start_variation_allocation'] = start_range
              variation['end_variation_allocation'] = end_range
              current_allocation += step_factor
            else
              variation['start_variation_allocation'] = -1
              variation['end_variation_allocation'] = -1
            end
          end
          whitelisted_variation = @bucketer.get_variation(
            targeted_variations_deep_clone,
            @bucketer.get_bucket_value_for_user(
              user_id
            )
          )
        else
          whitelisted_variation = targeted_variations[0]
        end
        whitelisted_variation
      end

      # It extracts the weights from all the variations inside the campaign
      # and scales them so that the total sum of eligible variations' weights become 100%
      #
      # 1. variations

      def scale_variation_weights(variations)
        total_weight = variations.reduce(0) { |final_weight, variation| final_weight + variation['weight'].to_f }
        if total_weight == 0
          weight = 100 / variations.length
          variations.each do |variation|
            variation['weight'] = weight
          end
        else
          variations.each do |variation|
            variation['weight'] = (variation['weight'] / total_weight) * 100
          end
        end
      end

      # Get the UserStorageData after looking up into get method
      # Being provided via UserStorageService
      #
      # @param[String]: Unique user identifier
      # @param[String]: Unique campaign key
      # @return[Hash|Boolean]: user_storage data

      def get_user_storage(user_id, campaign_key)
        unless @user_storage_service
          @logger.log(
            LogLevelEnum::DEBUG,
            format(LogMessageEnum::DebugMessages::NO_USER_STORAGE_SERVICE_LOOKUP, file: FILE)
          )
          return false
        end

        data = @user_storage_service.get(user_id, campaign_key)
        @logger.log(
          LogLevelEnum::INFO,
          format(
            LogMessageEnum::InfoMessages::LOOKING_UP_USER_STORAGE_SERVICE,
            file: FILE,
            user_id: user_id,
            status: data.nil? ? 'Not Found' : 'Found'
          )
        )
        data
      rescue StandardError
        @logger.log(
          LogLevelEnum::ERROR,
          format(LogMessageEnum::ErrorMessages::LOOK_UP_USER_STORAGE_SERVICE_FAILED, file: FILE, user_id: user_id)
        )
        false
      end

      # If UserStorageService is provided and variation was stored,
      # Get the stored variation
      # @param[String]            :user_id
      # @param[String]            :campaign_key campaign identified
      # @param[Hash]              :user_campaign_map BucketMap consisting of stored user variation
      #
      # @return[Object, nil]      if found then variation settings object otherwise None

      def get_stored_variation(user_id, campaign_key, user_campaign_map)
        return unless user_campaign_map['campaign_key'] == campaign_key

        variation_name = user_campaign_map['variation_name']
        @logger.log(
          LogLevelEnum::DEBUG,
          format(
            LogMessageEnum::DebugMessages::GETTING_STORED_VARIATION,
            file: FILE,
            campaign_key: campaign_key,
            user_id: user_id,
            variation_name: variation_name
          )
        )

        get_campaign_variation(
          @settings_file,
          campaign_key,
          variation_name
        )
      end

      # If UserStorageService is provided, save the assigned variation
      #
      # @param[String]              :user_id            Unique user identifier
      # @param[String]              :campaign_key       Unique campaign identifier
      # @param[String]              :variation_name     Variation identifier
      # @return[Boolean]                                true if found otherwise false

      def save_user_storage(user_id, campaign_key, variation_name)
        unless @user_storage_service
          @logger.log(
            LogLevelEnum::DEBUG,
            format(LogMessageEnum::DebugMessages::NO_USER_STORAGE_SERVICE_SAVE, file: FILE)
          )
          return false
        end
        new_campaign_user_mapping = {}
        new_campaign_user_mapping['campaign_key'] = campaign_key
        new_campaign_user_mapping['user_id'] = user_id
        new_campaign_user_mapping['variation_name'] = variation_name

        @user_storage_service.set(new_campaign_user_mapping)

        @logger.log(
          LogLevelEnum::INFO,
          format(LogMessageEnum::InfoMessages::SAVING_DATA_USER_STORAGE_SERVICE, file: FILE, user_id: user_id)
        )
        true
      rescue StandardError
        @logger.log(
          LogLevelEnum::ERROR,
          format(LogMessageEnum::ErrorMessages::SAVE_USER_STORAGE_SERVICE_FAILED, file: FILE, user_id: user_id)
        )
        false
      end
    end
  end
end

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

require_relative '../logger'
require_relative '../enums'
require_relative '../utils/campaign'
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
        # Check if user_storage_service provided is valid or not
        @user_storage_service = user_storage_service
        @bucketer = VWO::Core::Bucketer.new
        @settings_file = settings_file
      end

      # Returns variation for the user for the passed campaign-key
      # Check in User Storage, if user found, validate variation and return
      # Otherwise, proceed with variation assignment logic
      #
      #
      # @param[String]          :user_id             The unique ID assigned to User
      # @param[Hash]            :campaign            Campaign hash itslef
      # @return[String,String]                       ({variation_id, variation_name}|Nil): Tuple of
      #                                              variation_id and variation_name if variation allotted, else nil

      def get_variation(user_id, campaign)
        if campaign
          campaign_key = campaign['key']
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
          return variation['id'], variation['name']
        end

        variation_id, variation_name = get_variation_allotted(user_id, campaign)

        if variation_name
          save_user_storage(user_id, campaign_key, variation_name) if variation_name

          @logger.log(
            LogLevelEnum::INFO,
            format(
              LogMessageEnum::InfoMessages::VARIATION_ALLOCATED,
              file: FILE,
              campaign_key: campaign_key,
              user_id: user_id,
              variation_name: variation_name
            )
          )
        else
          @logger.log(
            LogLevelEnum::INFO,
            format(LogMessageEnum::InfoMessages::NO_VARIATION_ALLOCATED, file: FILE, campaign_key: campaign_key, user_id: user_id)
          )
        end
        [variation_id, variation_name]
      end

      # Returns the Variation Alloted for required campaign
      #
      # @param[String]  :user_id      The unique ID assigned to User
      # @param[Hash]    :campaign     Campaign hash for Unique campaign key
      #
      # @return[Hash]

      def get_variation_allotted(user_id, campaign)
        variation_id, variation_name = nil
        unless valid_value?(user_id)
          @logger.log(
            LogLevelEnum::ERROR,
            format(LogMessageEnum::ErrorMessages::INVALID_USER_ID, file: FILE, user_id: user_id, method: 'get_variation_alloted')
          )
          return variation_id, variation_name
        end

        if @bucketer.user_part_of_campaign?(user_id, campaign)
          variation_id, variation_name = get_variation_of_campaign_for_user(user_id, campaign)
          @logger.log(
            LogLevelEnum::DEBUG,
            format(
              LogMessageEnum::DebugMessages::GOT_VARIATION_FOR_USER,
              file: FILE,
              variation_name: variation_name,
              user_id: user_id,
              campaign_key: campaign['key'],
              method: 'get_variation_allotted'
            )
          )
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
        end
        [variation_id, variation_name]
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
          return nil, nil
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
          return variation['id'], variation['name']
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
        [nil, nil]
      end

      private

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
        if user_campaign_map[campaign_key] == campaign_key
          variation_name = user_campaign_map[:variationName]
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
          return get_campaign_variation(
            @settings_file,
            campaign_key,
            variation_name
          )
        end

        @logger.log(
          LogLevelEnum::DEBUG,
          format(
            LogMessageEnum::DebugMessages::NO_STORED_VARIATION,
            file: FILE,
            campaign_key: campaign_key,
            user_id: user_id
          )
        )
        nil
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

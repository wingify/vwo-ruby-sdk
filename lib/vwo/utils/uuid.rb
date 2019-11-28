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

require 'digest'
require_relative '../logger'
require_relative '../enums'
require_relative '../constants'

# Utility module for generating uuid
class VWO
  module Utils
    module UUID
      include VWO::Enums
      include VWO::CONSTANTS

      def self.parse(obj)
        str = obj.to_s.sub(/\Aurn:uuid:/, '')
        str.gsub!(/[^0-9A-Fa-f]/, '')
        [str[0..31]].pack 'H*'
      end

      def self.uuid_v5(uuid_namespace, name)
        uuid_namespace = parse(uuid_namespace)
        hash_class = ::Digest::SHA1
        version = 5

        hash = hash_class.new
        hash.update(uuid_namespace)
        hash.update(name)

        ary = hash.digest.unpack('NnnnnN')
        ary[2] = (ary[2] & 0x0FFF) | (version << 12)
        ary[3] = (ary[3] & 0x3FFF) | 0x8000
        # rubocop:disable Lint/FormatString
        '%08x-%04x-%04x-%04x-%04x%08x' % ary
        # rubocop:enable Lint/FormatString
      end

      VWO_NAMESPACE = uuid_v5(URL_NAMESPACE, 'https://vwo.com')

      # Generates desired UUID
      #
      # @param[Integer|String]      :user_id        User identifier
      # @param[Integer|String]      :account_id     Account identifier
      #
      # @return[Integer]                            Desired UUID
      #
      def generator_for(user_id, account_id)
        user_id = user_id.to_s
        account_id = account_id.to_s
        user_id_namespace = generate(VWO_NAMESPACE, account_id)
        uuid_for_account_user_id = generate(user_id_namespace, user_id)

        desired_uuid = uuid_for_account_user_id.delete('-').upcase

        VWO::Logger.get_instance.log(
          LogLevelEnum::DEBUG,
          format(
            LogMessageEnum::DebugMessages::UUID_FOR_USER,
            file: FileNameEnum::UuidUtil,
            user_id: user_id,
            account_id: account_id,
            desired_uuid: desired_uuid
          )
        )
        desired_uuid
      end

      # Generated uuid from namespace and name, uses uuid5
      #
      # @param[String]        :namespace    Namespace
      # @param[String)        :name         Name
      #
      # @return[String|nil]                UUID, nil if any of the arguments is empty
      def generate(namespace, name)
        VWO::Utils::UUID.uuid_v5(namespace, name) if name && namespace
      end
    end
  end
end

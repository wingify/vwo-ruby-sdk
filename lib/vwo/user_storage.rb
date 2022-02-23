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

class VWO
  # UserStorage Class is used to store user-variation mapping.
  # Override this class to implement your own functionality.
  # SDK will ensure to use this while bucketing a user into a variation.

  class UserStorage
    # To retrieve the stored variation for the user_id.
    #
    # @param[String]        :user_id            ID for user that needs to be retrieved.
    # @param[String]        :_campaign_key      Unique campaign key
    # @return[Hash]         :user_data          User's data.
    #
    def get(_user_id, _campaign_key); end

    # To store the the user variation-mapping
    # @param[Hash]    :user_data
    #
    def set(_user_data); end
  end
end

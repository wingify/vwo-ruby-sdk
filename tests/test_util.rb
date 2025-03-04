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

class TestUtil
    def self.get_random_arbitrary(min, max)
      # Reference - https://stackoverflow.com/a/1527820/2494535
      # Author - https://stackoverflow.com/users/58808/ionu%c8%9b-g-stan
      rand(min..max)
    end

    def self.get_users
      [
        'Ashley', 'Bill', 'Chris', 'Dominic', 'Emma', 'Faizan', 'Gimmy', 'Harry', 'Ian', 'John',
        'King', 'Lisa', 'Mona', 'Nina', 'Olivia', 'Pete', 'Queen', 'Robert', 'Sarah', 'Tierra',
        'Una', 'Varun', 'Will', 'Xin', 'You', 'Zeba'
      ]
    end

    def self.get_random_user
      users = get_users
      users[get_random_arbitrary(0, 9)]  # Random index between 0 and 9
    end
  end

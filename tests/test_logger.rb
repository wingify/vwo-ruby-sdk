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

require 'test/unit'
require_relative '../lib/vwo/logger'
require 'logger'
require 'stringio'

$stdout = StringIO.new

class VWO
  class Logger
    def log(_level, message)
      $stdout.puts(message)
    end
  end
end

class LoggerTest < Test::Unit::TestCase
  def setup
    @logger_instance = VWO::Logger.get_instance
  end

  def test_no_logger_passed
    assert_equal(@logger_instance.class, VWO::Logger)
  end
end

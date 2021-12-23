# Copyright 2019-2021 Wingify Software Pvt. Ltd.
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

require 'net/http'

class VWO
  module Utils
    class Request
      def self.get(url, params)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        uri.query = URI.encode_www_form(params)
        Net::HTTP.get_response(uri)
      end

      def self.post(url, params, post_data)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        uri.query = URI.encode_www_form(params)
        headers = {
          'Authorization'=>params[:env],
          'Content-Type' =>'application/json',
          'Accept'=>'application/json'
        }
        response = http.post(uri, post_data.to_json, headers)
        response
      end

      def self.event_post(url, params, post_data, user_agent_value)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        uri.query = URI.encode_www_form(params)
        headers = {
          'User-Agent' => user_agent_value,
          'Content-Type' =>'application/json',
          'Accept'=>'application/json'
        }
        response = http.post(uri, post_data.to_json, headers)
        response
      end
    end
  end
end

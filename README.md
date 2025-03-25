# ⚠️ [DEPRECATED] VWO Ruby SDK

**⚠️ This project is no longer actively developed. ⚠️**

**✅ We are only fixing critical bugs and security issues.**

**❌ No new features, enhancements, or non-critical updates will be added.**

#### Switch to *VWO Feature Management & Experimentation(FME)* – The Better Alternative! 🚀

VWO’s FME product empowers teams to seamlessly test, release, optimize, and roll back features across their entire tech stack while minimizing risk and maximizing business impact.

* Check out FME developer documentation [here](https://developers.vwo.com/v2/docs/fme-overview).
* Check [this](https://developers.vwo.com/v2/docs/sdks-release-info ) for the list of all FME-supported SDKs.

**💡 Need Help?**
For migration assistance or any questions, contact us at [support@vwo.com](support@vwo.com)

------

[![Gem version](https://badge.fury.io/rb/vwo-sdk.svg)](https://rubygems.org/gems/vwo-sdk)
[![CI](https://github.com/wingify/vwo-ruby-sdk/workflows/CI/badge.svg?branch=master)](https://github.com/wingify/vwo-ruby-sdk/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/wingify/vwo-ruby-sdk/branch/master/graph/badge.svg?token=6F5QQEGO5Q)](https://codecov.io/gh/wingify/vwo-ruby-sdk)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0)

This open source library allows you to A/B Test your Website at server-side.

## Requirements

* Works with 2.2.10 onwards

## Installation

```bash
gem install vwo-sdk
```

## Basic usage

**Importing and Instantiation**

```ruby
require 'vwo'

# Initialize client
vwo_client_instance = VWO.new(account_id, sdk_key)

# Initialize client with all parameters(explained in next section)
vwo_client_instance = VWO.new(account_id, sdk_key, custom_logger, UserStorage.new, true, settings_file)

# Get Settings
vwo_client_instance.get_settings

# Activate API
# With Custom Variables
options = { "custom_variable" => { "a" => "x"}}
variation_name = vwo_client_instance.activate(campaign_key, user_id, options)

# Without Custom Variables
options = {}
variation_name = vwo_client_instance.activate(campaign_key, user_id, options)

# GetVariation
# With Custom Variables
options = { "custom_variable" => { "a" => "x"}}
variation_name = vwo_client_instance.get_variation_name(campaign_key, user_id, options)

#Without Custom Variables
options = {}
variation_name = vwo_client_instance.get_variation_name(campaign_key, user_id, options)

# Track API
# With Custom Variables
options = { "custom_variable" => { "a" => "x"}}
is_successful = vwo_client_instance.track(campaign_key, user_id, goal_identifier, options)

# With Revenue Value
options = { "revenue_value" => 10.23}
is_successful = vwo_client_instance.track(campaign_key, user_id, goal_identifier, options)

# With both Custom Variables and Revenue Value
options = { "custom_variable" => { "a" => "x"}, "revenue_value" => 10.23}
is_successful = vwo_client_instance.track(campaign_key, user_id, goal_identifier, options)

# FeatureEnabled? API
# With Custom Varibles
options = { "custom_variable" => { "a" => "x"}}
is_successful = vwo_client_instance.feature_enabled?(campaign_key, user_id, options)

# Without Custom Variables
options = {}
is_successful = vwo_client_instance.feature_enabled?(campaign_key, user_id, options)

# GetFeatureVariableValue API
# With Custom Variables
options = { "custom_variable" => { "a" => "x"}}
variable_value = vwo_client_instance.get_feature_variable_value(campaign_key, variable_key, user_id, options)

# Without Custom Variables
options = {}
variable_value = vwo_client_instance.get_feature_variable_value(campaign_key, variable_key, user_id, options)

# Push API
is_successful = vwo_client_instance.push(tag_key, tag_value, user_id)
```

1. `account_id` - Account for which sdk needs to be initialized
1. `sdk_key` - SDK key for that account
1. `logger` - If you need to pass your own logger. Check documentation below
1. `UserStorage.new` - An object allowing `get` and `set` for maintaining user storage
1. `development_mode` - on/off (true/false). Default - false
1. `settings_file` - Settings file if already present during initialization. Its stringified JSON format.


**API usage**

**User Defined Logger**

There are two ways you can use your own custom logging

1. Override Existing Logging

    ```ruby
      class VWO::Logger
        def initialize(logger_instance)
          # Override this two create your own logging instance
          # Make sure log method is defined on it
          # i.e @@logger_instance = MyLogger.new(STDOUT)
          @@logger_instance = logger_instance || Logger.new(STDOUT)
        end

        # Override this method to handle logs in a custom manner
        def log(level, message)
          # Modify level & Message here
          # i.e message = "Custom message #{message}"
          @@logger_instance.log(level, message)
        end
      end
    ```

2. Pass your own logger during client initialization

`vwo_client_instance = VWO.new(account_id, sdk_key, user_defined_logger)`

***Note*** - Make sure your logger instance has `log` method which takes `(level, message)` as arguments.

**User Storage**

Use custom UserStorage

    ```ruby
    class VWO
      # Abstract class encapsulating user storage service functionality.
      # Override with your own implementation for storing
      # And retrieving the user.

      class UserStorage

        # Abstract method, must be defined to fetch the
        # User storage dict corresponding to the user_id.
        #
        # @param[String]        :user_id            ID for user that needs to be retrieved.
        # @return[Hash]         :user_storage_obj   Object representing the user.
        #
        def get(user_id, campaign_key)
          # example code to fetch it from DB column
          JSON.parse(User.find_by(vwo_id: user_id).vwo_user)
        end

        # Abstract method, must be to defined to save
        # The user dict sent to this method.
        # @param[Hash]    :user_storage_obj     Object representing the user.
        #
        def set(user_data)
            # example code to save it in DB
           User.update_attributes(vwo_id: user_data.userId, vwo_user: JSON.generate(user_data))
        end
      end
    end

    # Now use it to initiate VWO client instance
    vwo_client_instance = VWO.new(account_id, sdk_key, custom_logger, UserStorage.new)
    ```

## Documentation

Refer [Official VWO Documentation](https://developers.vwo.com/reference#fullstack-introduction)


## Code syntax check

```bash
bundle exec rubocop lib
```

## Setting up Local development environment

```bash
chmod +x ./start-dev.sh
bash start-dev.sh
gem install
```

## Running Unit Tests

```bash
ruby tests/test_all_tests.rb
```

## Third-party Resources and Credits

Refer [third-party-attributions.txt](https://github.com/wingify/vwo-ruby-sdk/blob/master/third-party-attributions.txt)

## Changelog

Refer [CHANGELOG.md](https://github.com/wingify/vwo-ruby-sdk/blob/master/CHANGELOG.md)

## Contributing

Please go through our [contributing guidelines](https://github.com/wingify/vwo-ruby-sdk/blob/master/CONTRIBUTING.md)

## Code of Conduct

[Code of Conduct](https://github.com/wingify/vwo-ruby-sdk/blob/master/CODE_OF_CONDUCT.md)

## License

[Apache License, Version 2.0](https://github.com/wingify/vwo-ruby-sdk/blob/master/LICENSE)

Copyright 2019-2025 Wingify Software Pvt. Ltd.

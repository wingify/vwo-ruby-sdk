# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.42.0] - 2025-03-04

### Added

- Added support for new bucketing algorithm

## [1.41.0] - 2024-27-08

### Added

- Added support for handling the below operators in targeting and whitelisting i.e.

  - Greater than
  - Greater than equal to
  - Less than
  - Less than equal to

## [1.40.0] - 2024-04-08

### Added

- Support for user IP Address and browser user agent to help with bot elimination, IP specific opt out and more options for post segmentation
- Support for `event_properties` for Data360 enabled accounts

## [1.38.0] - 2022-27-07

### Changed

- Fix invoking `integrations` hook twice when variation is alloted to a non-whitelisted new user and pre-segmentation gets passed.

## [1.37.1] - 2022-25-04

### Changed

- Code properly linted, fixed rubocop warnings and errors

## [1.36.0] - 2022-04-04

### Changed

- Fix resolving `vwo_sdk_log_messages` dependency

## [1.35.0] - 2022-03-28

### Changed

- Always check targeting conditions
  - The option `Once` is selected by default in the VWO Application, which means the user segment condition is only checked once and the same variation is served to the user on every subsequent call to the SDK's APIs.
  - If you choose `Always`, the user is evaluated against the segment condition on every call to the SDK's APIs.
- Instead of multiple tracking calls in case of global goals, now one single batch call will be made to track different goals of different campaigns having same goal-identifier.
- Instead of multiple tracking calls in case of pushing more than one custom dimension, now one single batch call will be made to push custom dimension map.
- Integrated VWO SDK Log Messages repo instead of hardcoding messages in every VWO server-side SDK.
- Old logs are revamped. New logs that would help in better debugging are added.

## [1.30.0] - 2022-09-03

### Changed

- Reading `isBucketingSeedEnabled` flag correctly so that campaign-id will be used for bucketing a user when this flag value is truthy.

## [1.29.1] - 2022-02-25

### Changed

- VWO Log messages dependency added to Gemfile and .gemspec file

## [1.29.0] - 2022-02-23

### Changed

- Tracking data for the `Data Residency` enabled VWO accounts will be sent to the configured location
- Update year in all the copyright and liense headers

## [1.28.1] - 2022-01-23

### Changed

- Fix issue when `nil` is passed as `options` for the `track` API. Fixes #5.

## [1.28.0] - 2021-12-23

### Changed

- In case you want to opt out of tracking by VWO, simply call the `set_opt_out` API. This will exclude all the users from any kind of tracking by VWO. This is useful when you just want to make the VWO SDK ineffective without actually removing the associated code.

  `set_opt_out` API will also remove unwanted memory footprint by destructing all the instance variables. Calling any other API after this will not be effective i.e. no decision-making or impression would be made to VWO.

  ```ruby
  vwo_client_instance.set_opt_out()
  ```

  If you want to opt-in again for tracking by VWO SDK, reinitialize the SDK with the latest settings.

## [1.25.0] - 2021-12-23

### Added

- Support for pushing multiple custom dimensions at once. Earlier, you had to call push API multiple times for tracking multiple custom dimensions as follows:

  ```ruby
  vwo_client_instance.push('browser', 'chrome', user_id)
  vwo_client_instance.push('price', '20', user_id)
  ```

  Now, you can pass an hash

  ```ruby
  custom_dimension_map = {
    browser: 'chrome',
    price: '20'
  }

  vwo_client_instance.push(custom_dimension_map, user_id)
  ```

  Multiple asynchronous tracking calls would be initiated in this case.

### Changed

- If Events Architecture is enabled for your VWO account, all the tracking calls being initiated from SDK would now be `POST` instead of `GET` and there would be single endpoint i.e. `/events/t`. This is done in order to bring events support and building advanced capabilities in future.

- For events architecture accounts, tracking same goal across multiple campaigns will not send multiple tracking calls. Instead, one single `POST` call would be made to track the same goal across multiple different campaigns running on the same environment.

- Multiple custom dimension can be pushed via `push` API. For events architecture enabled account, only one single asynchronous call would be made to track multiple custom dimensions.

  ```ruby
  custom_dimension_map = {
    browser: 'chrome',
    price: '20'
  }
  vwo_client_instance.push(custom_dimension_map, user_id)
  ```

## [1.24.1] - 2021-12-09

### Changed

- Remove `should_track_returning_user` option as FullStack campaigns show unique visitors and conversions count. Duplicate visitors/conversions tracking calls would not be made if User Storage Service is used.

## [1.24.0] - 2020-12-08

### Changed

- User IDs passed while applying whitelisting in a campaign from VWO Application will now be hashed. Inside settings-file, all User IDs will be hashed for security reasons. SDK will hash the User ID passed in the different APIs before matching it with the campaigns settings. This is feature-controlled from VWO i.e. we are only rolling this functionality gradually. Please reach out to the support team in case you want to opt-in early for this feature for your VWO account.

## [1.23.2] - 2020-11-30

### Changed

- SDK Key will not be logged in any log message, for example, tracking call logs.
- Campaign name will be available in settings and hence, changed settings-schema validations.
- `campaign_name` will be available in integrations callback, if callback is defined.

## [1.23.1] - 2020-10-21

### Changed

- Updated whitelisting logs for Feature Rollout campaign
- Test cases added to verify whitelisting cases in Feature Rollout campaign

## [1.23.0] - 2021-10-11

### Changed

- Added support for passing hash with keys as Symbol/String in different APIs

  ```ruby
  # keys as Symbol
  {
    test: "some value",
    num:  123
  }

  # keys as String
  {
    "test" => "some value",
    "num"  =>  123
  }
  ```

## [1.22.1] - 2021-09-02

### Changed

- Used `push` API instead of `append` to support older versions of ruby.

## [1.22.0] - 2021-09-02

### Added

- Introducing support for Mutually Exclusive Campaigns. By creating Mutually Exclusive Groups in VWO Application, you can group multiple FullStack A/B campaigns together that are mutually exclusive. SDK will ensure that visitors do not overlap in multiple running mutually exclusive campaigns and the same visitor does not see the unrelated campaign variations. This eliminates the interaction effects that multiple campaigns could have with each other. You simply need to configure the group in the VWO application and the SDK will take care what to be shown to the visitor when you will call the `activate` API for a given user and a campaign.

### Changed

- Sending visitor tracking call for Feature Rollout campaign when `feature_enabled?` API is used. This will help in visualizing the overall traffic for the respective campaign's report in the VWO application.
- Use Campaign ID along with User ID for bucketing a user in a campaign. This will ensure that a particular user gets different variation for different campaigns having similar settings i.e. same campaign-traffic, number of variations, and variation traffic.

## [1.16.0] - 2021-09-02


### Added

- Feature Rollout and Feature Test campaigns now supports `JSON` type variable which can be created inside VWO Application. This will help in storing grouped and structured data.

## [1.15.0] - 2021-08-22

### Changed

- Fix bug which was causing SDK to throw SyntaxError on versions `>= 2.3.0` and `< 2.5.0`
- Removed Travis CI integration
- Added GitHub Action for running tests and submitting coverage to Codecov tool

## [1.14.1] - 2021-08-10

### Changed

- Update `track` API to accept `options` instead of parametered arguments.

```ruby
options = {
  "revenue_value" => 10,
  "custom_variables": {},
  "variation_targeting_variables": {},
  "should_track_returning_user": true,
  "goal_type_to_track" => "ALL"
}
```


## [1.14.0] - 2021-07-06

### Added

- Webhooks support
  - New API `get_and_update_settings_file` to fetch and update settings-file in case of webhook-trigger
- Event Batching
  - Added support for batching of events sent to VWO server
  - Introduced `batch_vents` config in initializzation API for setting when to send bulk events
  - Added `flush_events` API to manually flush the batch events queue whne `batch_events` config is passed. Note: `batch_events` config i.e. `events_per_request` and `request_time_interval` won't be considered while manually flushing

  ```ruby
  def flush_callback(error, events)
    puts events
  end

  vwo_client_instance = VWO.new(
    config['account_id'],
    config['sdk_key'],
    batch_events: {
      events_per_request: 2,
      request_time_interval: 100,
      flushCallback: method(:flush_callback)
    }
  )
  ```

  - If requestTimeInterval is passed, it will only set the timer when the first event will arrive
  - If requestTimeInterval is provided, after flushing of events, new interval will be registered when the first event will arrive
  - If eventsPerRequest is not provided, the default value of 600 i.e. 10 minutes will be used
  - If requestTimeInterval is not provided, the default value of 100 events will be used

  ```ruby
  # (optional): Manually flush the batch events queue to send impressions to VWO server.
  vwo_client_instance.flush_events()
  ```

- Expose lifecycle hook events. This feature allows sending VWO data to third party integrations. Introduce `integrations` key in initialization API to enable receiving hooks for the third party integrations.

  ```ruby
  def integrations_callback(properties)
    puts properties
  end

  vwo_client_instance = VWO.new(
    config['account_id'],
    config['sdk_key'],
    integrations: {
      callback: method(:integrations_callback)
    }
  )
  ```

- Global Goals Tracking support
  - Update `track` API to handle duplicate and unique conversions and corresponding changes in initialiation API
  - Update `track` API to track a goal globally across campaigns with the same goalIdentififer and corresponding changes in initialiation API

  ```ruby
  # it will track goal having `goal_identifier` of campaign having `campaign_key` for the user having `user_id` as id.
  vwo_client_instance.track(campaign_key, user_id, goal_identifier, {})

  # it will track goal having `goal_identifier` of campaigns having `campaign_key1` and `campaign_key2` for the user having `user_id` as id.

  vwo_client_instance.track([campaign_key1, campaign_key2], user_id, goal_identifier, {})

  # it will track goal having `goal_identifier` of all the campaigns
  vwo_client_instance.track(nil, user_id, goalIdentifier, {})
  ```

### Changed

- Send environment token in every network call initiated from SDK to the VWO server. This will help in viewing campaign reports on the basis of environment.
- If User Storage Service is provided, do not track same visitor multiple times.
  You can pass shouldTrackReturningUser as true in case you prefer to track duplicate visitors.

  ```ruby
  vwo_client_instance.activate(
      campaign_key,
      user_id,
      {
        should_track_returning_user: true
      }
    )
  ```

  Or, you can also pass `should_track_returning_user` at the time of instantiating VWO SDK client. This will avoid passing the flag in different API calls.

  ```ruby
  should_track_returning_user = true
  vwo_client_instance = VWO.new(account_id, sdk_key, should_track_returning_user)
  ```

  If `should_track_returning_user` param is passed at the time of instantiating the SDK as well as in the API options as mentioned above, then the API options value will be considered.

  * If User Storage Service is provided, campaign activation is mandatory before tracking any goal, getting variation of a campaign, and getting value of the feature's variable.

  **Correct Usage**

  ```ruby
  vwo_client_instance.activate(
    campaign_key,
    user_id
  )

  vwo_client_instance.track(
    campaign_key,
    user_id,
    campaign_goal_identifier
  )
  ```

  **Wrong Usage**

  ```ruby
  # Calling track API before activate API
  # This will not track goal as campaign has not been activated yet.
  vwo_client_instance.track(
    campaign_key,
    user_id,
    campaign_goal_identifier
  )

  # After calling track APi
  vwo_client_instance.activate(
    campaign_key,
    user_id
  )
  ```


## [1.6.0] - 2020-05-06

### Added

- Forced Variation capabilites
- Introduced `Forced Variation` to force certain users into specific variation. Forcing can be based on User IDs or custom variables defined.
### Changed

- All existing APIs to handle variation-targeting-variables as an option for forcing variation
- Code refactored to support Whitelisting.

## [1.5.0] - 2020-02-20
### Breaking Changes
To prevent ordered arguments and increasing use-cases, we are moving all optional arguments to be passed via `options`.

- customVariables argument in APIs: `activate`, `get_variation_name`, `track`, `is_feature_enabled`, and `get_feature_variable_value` will now be passed via `options`.
- `revenueValue` parameter in `track` API via `options`

#### Before
```ruby
# activae API
vwo_client_instance.activate(campaign_key, user_id)
# getVariation API
vwo_client_instance.get_variation(campaign_key, user_id)
# track API
vwo_client_instance.track(campaign_key, user_id, goalIdentifier, revenueValue)
```
#### After
```ruby
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
```
### Added
- Feature Rollout and Feature Test capabilities
- Pre and Post segmentation capabilites
  Introduced new Segmentation service to evaluate whether user is eligible for campaign based on campaign pre-segmentation conditions and passed custom-variables
### Changed
- Existing APIs to handle new type of campaigns i.e. feature-rollout and feature-test
- All existing APIs to handle custom-variables for tageting audience
- Code refactored to support feature-rollout, feature-test, campaign tageting and post segmentation

## [1.3.0] - 2019-11-28
### Changed
- Change MIT License to Apache-2.0
- Added apache copyright-header in each file
- Add NOTICE.txt file complying with Apache LICENSE
- Give attribution to the third-party libraries being used and mention StackOverflow

## [1.0.0] - 2019-11-26
### Added
- First release with Server-side A/B capabilities

# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

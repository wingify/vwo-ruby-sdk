# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2020-02-20
### Breaking Changes
To prevent ordered arguments and increasing use-cases, we are moving all optional arguments to be passed via `kwargs`.

- customVariables argument in APIs: `activate`, `get_variation`, `track`, `is_feature_enabled`, and `get_feature_variable_value` will now be passed via `kwargs`.
- `revenueValue` parameter in `track` API via `kwargs`

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

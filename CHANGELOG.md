# zeebe_bpmn_rspec

## v0.4.0 (unreleased)
- Add `ttl_ms` option for `publish_message`.
- Add `update_retries` method to `ActivatedJob` class.
- Add `set_variables` helper.

## v0.3.1
- Use consistent activate request timeout.
- Provide a better error when a job is not activated.

## v0.3.0
- Add custom matchers, `have_variables`, `have_headers`, and `have_activated`.

## v0.2.0
- Add `retries` option to `ActivatedJob#and_fail`.
- Add method aliases: `and_complete` (`complete`), `and_fail` (`fail`), `and_throw_error` (`throw_error`).

## v0.1.0
- Initial version

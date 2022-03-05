# zeebe_bpmn_rspec

## unpublished
- Add `called` option for `activate_job`.
- Update the validation assertions in `activate_job` to have more helpful error messages.

## v1.0.1
- Fix dependency issue preventing use of zeebe-client versions 0.15 or above.

## v1.0.0
- Support Zeebe 1.0.0. Method names now use `process` instead of `workflow`
  to match the renaming in Zeebe. Previous methods are deprecated and will be
  removed in a future release.

## v0.5.0
- Require Ruby 2.6 or later.
- Require `worker` to be specified when activating a job. This argument is
  defaulted but can no longer be specified as blank.

## v0.4.1
- Allow `with_workflow_instance` to be called without a block.
- Allow `worker` to be specified when activating a job.
- Expose `workflow_instance_key` for activated jobs.

## v0.4.0
- Add `ttl_ms` option for `publish_message`.
- Add `update_retries` method to `ActivatedJob` class.
- Add `set_variables` helper.
- Add support for `:fetch_variables` option when activating jobs.

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

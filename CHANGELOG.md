# Changelog

All notable changes to the Evertimer Redmine plugin will be documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0-rc.1] - 2026-09-14

First tagged release. Everything below is relative to the untagged `0.0.1` builds that were only ever available from the `feat/user-stats` branch.

### Added

- `GET /evertimer/user_stats?include=user` — the stats payload can now include the requesting user's identity (`id`, `firstname`, `lastname`, `avatar_url`) in one round trip, so a client does not need a second request.
- Conditional requests for `GET /evertimer/user_stats`: a weak `ETag` and `304 Not Modified` support, so unchanged stats can be served without re-querying.
- A settings screen (**Administration** > **Plugins** > **Evertimer Redmine plugin** > **Configure**) to mark projects, trackers, issue statuses, time-tracking activities and custom-field values as non-billable.
- A composite `time_entries (user_id, spent_on)` database index to speed up the statistics query (migration `002`, replacing the single-column `spent_on` index from migration `001`).
- Explicit `requires_redmine version_or_higher: '4.1.1'` compatibility declaration in `init.rb`.

### Changed

- `GET /evertimer/user_stats` rewritten as a single-pass, cached query. Week boundaries now follow the Redmine instance's *start of week* setting, and the day boundary follows the requesting user's own timezone, rather than the server's.
- `GET /evertimer/custom_fields.json` now returns only a fixed 12-attribute whitelist per custom field, instead of the full ActiveRecord record.
- Non-billable "this week" / "this month" date ranges now calculate to the actual end of the period, instead of stopping at today.
- Archived projects are hidden from the non-billable project picker, while projects already marked non-billable stay selectable.
- The plugin no longer overrides Redmine's own confirmation text for deleting time entries.
- Relicensed from Apache License 2.0 to the **GNU General Public License, version 2**, matching Redmine's own license (see *License change* below).

### Fixed

- Non-billable criteria saved with a blank value no longer incorrectly mark time entries as non-billable.
- Custom-field names are escaped on the settings screen.
- The wiki toolbar now renders correctly on custom-field rows added dynamically from the settings dropdown.
- A missing template row is guarded and cloned instead of copied via `outerHTML`.
- Ukrainian locale: the delete confirmation now says "custom field" instead of a mistranslated "client field".

### Security

- Both endpoints now require a valid Redmine API key. A missing or invalid key returns `401 Unauthorized`; previously a Redmine instance running in public mode could return a `200` response with zero hours to an anonymous caller.
- Redmine's session-expiration check, previously skipped on both endpoints, is enforced again.
- When a request carries both a browser session and an API key, the API key now decides the user.

### License change

As of this release the plugin is licensed under **GPLv2** instead of Apache License 2.0, to match Redmine itself. See `LICENSE` and the README's *Copyright and Licensing* section.

## [0.0.1] - 2024-03-21

Initial, untagged implementation, available only from the `feat/user-stats` branch and reported as version `0.0.1` in Redmine's plugin list.

### Added

- Initial plugin registration and the `GET /evertimer/user_stats` endpoint (sum of tracked hours for today, this week and this month).
- The `GET /evertimer/custom_fields.json` endpoint.

[Unreleased]: https://github.com/everlabs/evertimer_redmine_plugin/compare/v1.0.0-rc.1...HEAD
[1.0.0-rc.1]: https://github.com/everlabs/evertimer_redmine_plugin/compare/9c97ac8...v1.0.0-rc.1
[0.0.1]: https://github.com/everlabs/evertimer_redmine_plugin/commit/025592b

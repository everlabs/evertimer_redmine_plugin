# Changelog

All notable changes to the Evertimer Redmine plugin will be documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - Unreleased

First tagged release. Changes below are relative to the untagged `0.0.1` baseline.

### Added

- `GET /evertimer/custom_fields.json` — a new endpoint returning the `TimeEntryCustomField` records visible to the requesting user, narrowed to a fixed 12-attribute whitelist per field.
- A settings screen (**Administration** > **Plugins** > **Evertimer plugin** > **Configure**) to mark projects, trackers, issue statuses, time-tracking activities and custom-field values as non-billable, replacing the old hardcoded lookup for a custom field or activity literally named "Non-Billable"/"Non-billable". A non-billable activity also covers its project-level overrides.
- `GET /evertimer/user_stats?include=user` — the stats payload can now include the requesting user's identity (`id`, `firstname`, `lastname`, `avatar_url`) in one round trip, so a client does not need a second request.
- Conditional requests for `GET /evertimer/user_stats`: a weak `ETag` and `304 Not Modified` support, so unchanged stats can be served without re-querying.
- A composite `time_entries (user_id, spent_on)` database index to speed up the statistics query (migration `002`, replacing the single-column `spent_on` index added by migration `001` in the `0.0.1` baseline).
- Explicit `requires_redmine version_or_higher: '4.1.1'` compatibility declaration in `init.rb`.

### Changed

- `GET /evertimer/user_stats` rewritten as a single-pass, cached query. Week boundaries now follow the Redmine instance's *start of week* setting, and the day boundary follows the requesting user's own timezone, rather than the server's.
- The plugin no longer overrides Redmine's own confirmation text for deleting time entries.
- Relicensed from Apache License 2.0 to the **GNU General Public License, version 2**, matching Redmine's own license (see *License change* below).

### Fixed

- Non-billable criteria saved with a blank value no longer incorrectly mark time entries as non-billable.
- Archived projects are hidden from the non-billable project picker, while projects already marked non-billable stay selectable.
- Custom-field names are escaped on the settings screen.
- The wiki toolbar now renders correctly on custom-field rows added dynamically from the settings dropdown.
- A missing template row is guarded and cloned instead of copied via `outerHTML`.
- Ukrainian locale: the delete confirmation now says "custom field" instead of a mistranslated "client field".

### Security

- Both endpoints now require an authenticated user (a Redmine API key or a logged-in session). API requests without valid credentials get `401 Unauthorized`; the `0.0.1` baseline had no such check, so a Redmine instance running in public mode could return a `200` response with zero hours to an anonymous caller.
- Redmine's session-expiration check is enforced on both endpoints (the `0.0.1` baseline skipped it).
- When a request carries both a browser session and an API key, the API key now decides the user.

### License change

As of this release the plugin is licensed under **GPLv2** instead of Apache License 2.0, to match Redmine itself. See `LICENSE` and the README's *Copyright and Licensing* section.

## [0.0.1] - 2024-03-27

The untagged baseline at commit `2b1651e`, shown as version `0.0.1` in Redmine's plugin list.

### Added

- Initial plugin registration and the `GET /evertimer/user_stats` endpoint: total hours for today, this week and this month for `User.current`, using `Date.current` (server time, not the user's own timezone) for all three ranges.
- A billable/non-billable split on that same endpoint, but only when a `TimeEntryCustomField` happened to be named exactly "Non-Billable" or a `TimeEntryActivity` happened to be named exactly "Non-billable" — there was no settings screen.
- A single-column `time_entries.spent_on` database index (migration `001`).

[Unreleased]: https://github.com/everlabs/evertimer_redmine_plugin/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/everlabs/evertimer_redmine_plugin/compare/2b1651e...v1.0.0
[0.0.1]: https://github.com/everlabs/evertimer_redmine_plugin/commit/2b1651e

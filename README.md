EverTimer Redmine plugin
========================
Extends the Capabilities of the EverTimer Chrome Extension

Compatibility
-------------

Tested on Redmine 5.0.5; 4.1.1 compatibility maintained at API level.

| Redmine | Ruby | Rails | Status |
|---------|------|-------|--------|
| v5.0.5 | v3.1.3 | v6.1.7.2 | **Tested** — installed, migrated and exercised end-to-end on a clean instance |
| v4.1.1 | v2.6.6 | v5.2.4.2 | **API-level compatibility** — the plugin source is kept free of APIs introduced after Rails 5.2 / Ruby 2.6, verified by a static sweep of every Ruby file in `app/`, `db/`, `config/` and `init.rb`. No live 4.1.1 build was tested. |

Features
--------

This plugin extends the capabilities of the [EverTimer](https://chromewebstore.google.com/detail/evertimer/kjbdlnkafjlgnbmbeihkampliednpmgk) Chrome extension by providing two API endpoints:

1. **User Statistics** (`GET /evertimer/user_stats`): the sum of TimeEntry hours for today, this week and this month for the requesting user, together with the billable portion of each. Non-billable time is classified through the plugin's own settings screen (non-billable projects, trackers, issue statuses, time-tracking activities and custom-field values). Optionally returns the requesting user's identity with `?include=user`.

2. **Custom Fields** (`GET /evertimer/custom_fields.json`): the `TimeEntryCustomField` records visible to the requesting user, narrowed to the twelve attributes EverTimer actually needs to render a custom-field input. This addresses limitations with the core Redmine API endpoint `/custom_fields.json`, which requires admin privileges and returns comprehensive details unnecessary for [EverTimer](https://chromewebstore.google.com/detail/evertimer/kjbdlnkafjlgnbmbeihkampliednpmgk).

Configuration
-------------

The plugin requires `Enable REST web service` to be enabled in your Redmine Settings. To do so go to **Settings** > **API** and ensure that the **Enable REST web service** option is checked. You can find it at `https://your-redmine-domain/settings?tab=api`
![Enable REST web service](images/configure_redmine.png?raw=true)

Non-billable classification is configured per Redmine instance under **Administration** > **Plugins** > **Evertimer Redmine plugin** > **Configure**.

Installation
------------

1. Copy your plugin directory into `#{RAILS_ROOT}/plugins`. If you are downloading the plugin directly from GitHub, you can do so by navigating to your plugin directory and using the following command:
```bash
git clone https://github.com/everlabs/evertimer_redmine_plugin.git
```
The plugin directory must be named `evertimer_redmine_plugin` — Redmine derives both the plugin identifier and the mirrored asset path (`public/plugin_assets/evertimer_redmine_plugin`) from the directory name.

2. After copying the plugin into the appropriate directory, run its migrations from the Redmine root:
```bash
bundle exec rake redmine:plugins:migrate NAME=evertimer_redmine_plugin RAILS_ENV=production
```
The `NAME=` argument scopes the run to this plugin only, so other installed plugins are left alone.

3. Restart Redmine to apply the changes.

### Uninstalling / rolling back

1. Roll the plugin's migrations back from the Redmine root — this drops the index the plugin added and leaves no plugin rows behind in `schema_migrations`:
```bash
bundle exec rake redmine:plugins:migrate NAME=evertimer_redmine_plugin VERSION=0 RAILS_ENV=production
```
2. Remove the plugin directory (`#{RAILS_ROOT}/plugins/evertimer_redmine_plugin`) and its mirrored assets (`#{RAILS_ROOT}/public/plugin_assets/evertimer_redmine_plugin`).
3. Restart Redmine.

Run step 1 **before** removing the directory: the rake task needs the plugin's own migration files to know how to reverse them.

API
---

All endpoints authenticate with Redmine's standard REST API key. Send it as a header:

```
X-Redmine-API-Key: your_api_key
Accept: application/json
```

Find your API key at `https://your-redmine-domain/my/api_key`.

### `GET /evertimer/user_stats`

Returns six keys — total and billable hours for today, this week and this month — for the user the API key belongs to. Week boundaries follow the Redmine instance's `start_of_week` setting, and the day boundary follows the user's own timezone.

```bash
curl -H "X-Redmine-API-Key: your_api_key" -H "Accept: application/json" \
  https://your-redmine-domain/evertimer/user_stats
```

```json
{
  "today": 7.65,
  "this_week": 40.97,
  "this_month": 160.51,
  "today_billable": 6.12,
  "this_week_billable": 35.28,
  "this_month_billable": 140.73
}
```

### `GET /evertimer/user_stats?include=user`

Adds a nested `user` object describing the requesting user, so a client can fetch its stats and its identity in one round trip. The six stats keys are unchanged and keep their order; `user` is appended last.

```bash
curl -H "X-Redmine-API-Key: your_api_key" -H "Accept: application/json" \
  "https://your-redmine-domain/evertimer/user_stats?include=user"
```

```json
{
  "today": 7.65,
  "this_week": 40.97,
  "this_month": 160.51,
  "today_billable": 6.12,
  "this_week_billable": 35.28,
  "this_month_billable": 140.73,
  "user": {
    "id": 191,
    "firstname": "Ruslan",
    "lastname": "Taranenko",
    "avatar_url": "https://www.gravatar.com/avatar/58a30aee972688634601de224f7f7701?default=monsterid"
  }
}
```

- `avatar_url` is computed exactly the way Redmine's own users API computes it, and the key is **absent** — not `null` — when Gravatar is disabled for the instance or the user has no email address. Clients should fall back to their own default avatar when the key is missing.
- The payload deliberately carries **no API key and no email address**. A client that already stores the user's key must keep it when merging this object.
- Any other `include` value, or no `include` at all, returns the plain six-key body above.

### Conditional requests (ETag / 304)

Both `user_stats` variants answer with a **weak** ETag and revalidation headers:

```
ETag: W/"4d8cdab9db89b304b52d2567ebd082e3"
Cache-Control: max-age=0, private, must-revalidate
Vary: Accept
```

Echo the header value **verbatim — including the `W/` prefix and the quotes** — in `If-None-Match`:

```bash
curl -i -H "X-Redmine-API-Key: your_api_key" -H "Accept: application/json" \
  -H 'If-None-Match: W/"4d8cdab9db89b304b52d2567ebd082e3"' \
  https://your-redmine-domain/evertimer/user_stats
```

A matching validator returns **`304 Not Modified` with an empty body**, before any statistics query runs.

- Validators are **per variant**: the ETag of `/evertimer/user_stats` and the ETag of `/evertimer/user_stats?include=user` are different values and each rejects the other. Cache them separately.
- The plain ETag changes when the user's time entries change or the plugin settings are saved. The `include=user` ETag additionally changes when the user's own profile changes, so a renamed user is never served a stale name behind a 304.

### Authentication and errors

| Request | Response |
|---------|----------|
| Valid API key | `200` with the JSON body |
| Invalid API key | `401 Unauthorized`, empty body, `WWW-Authenticate: Basic realm="Redmine API"` |
| No API key | `401 Unauthorized`, empty body, same header |

Both endpoints require a logged-in user, so a Redmine instance running in public mode still refuses anonymous callers. The `401` is negotiated only for API requests — always send `Accept: application/json` (or use the `.json` suffix), otherwise Redmine answers a browser-style `302` redirect to the login page.

### `GET /evertimer/custom_fields.json`

Returns a top-level JSON **array** of the `TimeEntryCustomField` records visible to the requesting user. A user who can see no time-entry custom fields receives `[]`.

```bash
curl -H "X-Redmine-API-Key: your_api_key" \
  https://your-redmine-domain/evertimer/custom_fields.json
```

Each element carries exactly these twelve attributes:

| Attribute | Notes |
|-----------|-------|
| `id` | Integer — identifies the field when submitting a time entry |
| `name` | Display label |
| `description` | Help text, `""` when unset |
| `field_format` | Redmine's format identifier (`string`, `list`, `bool`, `date`, …) |
| `format_store` | Object with format-specific settings (e.g. `edit_tag_style`, `url_pattern`) |
| `possible_values` | Array of allowed values for list-style formats |
| `multiple` | Boolean — whether the field accepts several values |
| `min_length` | Integer or `null` |
| `max_length` | Integer or `null` |
| `regexp` | Validation pattern, `""` when unset |
| `is_required` | Boolean |
| `default_value` | Pre-filled value, may be `null` |

```json
[
  {
    "id": 22,
    "name": "CF_List",
    "field_format": "list",
    "possible_values": ["lista", "lisb", "listc"],
    "regexp": "",
    "min_length": null,
    "max_length": null,
    "is_required": false,
    "default_value": "lisb",
    "multiple": false,
    "format_store": { "url_pattern": "", "edit_tag_style": "" },
    "description": ""
  }
]
```

Nothing beyond these twelve attributes leaves the server — internal columns such as visibility and ordering flags are not exposed.

Issues
------

We value your feedback and contributions! Feel free to submit issues, enhancement requests, and feature suggestions through the project's issue tracker. Your input helps us to make our plugin better for everyone.

Contributing
------------

We welcome contributions! Please review our [contributing guidelines](CONTRIBUTING.md) before submitting pull requests or issues. Ensure you merge the latest changes from "upstream" before making a pull request.

Copyright and Licensing
-----------------------

This project is licensed under the Apache 2.0 license. Contributors retain the copyright of their contributions but must license them under the Apache 2.0 license for inclusion in the main repository.

License Summary
---------------

You can copy and paste the Apache 2.0 license summary from below.

```
Copyright 2025 by Everlabs

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

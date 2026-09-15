EverTimer Redmine plugin
========================

[![Latest release](https://img.shields.io/github/v/release/everlabs/evertimer_redmine_plugin?include_prereleases&sort=semver&label=release)](https://github.com/everlabs/evertimer_redmine_plugin/releases)
[![License: GPL-2.0](https://img.shields.io/badge/license-GPL--2.0-blue.svg)](LICENSE)
[![Redmine](https://img.shields.io/badge/Redmine-5.0%20%7C%206.1%20%7C%207.0-blue)](#compatibility)
[![Chrome Web Store](https://img.shields.io/badge/Chrome%20Web%20Store-Evertimer-4285F4?logo=googlechrome&logoColor=white)](https://chromewebstore.google.com/detail/evertimer/kjbdlnkafjlgnbmbeihkampliednpmgk)

Extends the Capabilities of the EverTimer Chrome Extension

Compatibility
-------------

Tested on Redmine 7.0.1, 6.1.1 and 5.0.5; 4.1.1 compatibility maintained at API level.

| Redmine | Ruby | Rails | Status |
|---------|------|-------|--------|
| v7.0.1 | v4.0.6 | v8.1.3.1 | **Tested** — plugin registered, both migrations forward and back, both endpoints, settings screen, and the extension exercised end-to-end against a restored production-shaped copy |
| v6.1.1 | v3.4.9 | v7.2.3 | **Tested** — same subset, same result |
| v5.0.5 | v3.1.3 | v6.1.7.2 | **Tested** — installed, migrated and exercised end-to-end on a clean instance |
| v4.1.1 | v2.6.6 | v5.2.4.2 | **API-level compatibility** — the plugin source is kept free of APIs introduced after Rails 5.2 / Ruby 2.6, verified by a static sweep of every Ruby file in `app/`, `db/`, `config/` and `init.rb`. No live 4.1.1 build was tested. |

Features
--------

This plugin extends the capabilities of the [EverTimer](https://chromewebstore.google.com/detail/evertimer/kjbdlnkafjlgnbmbeihkampliednpmgk) Chrome extension by providing two API endpoints:

1. **User Statistics** (`GET /evertimer/user_stats`): the sum of TimeEntry hours for today, this week and this month for the requesting user, together with the billable portion of each. Non-billable time is classified through the plugin's own settings screen (non-billable projects, trackers, issue statuses, time-tracking activities and custom-field values). Optionally returns the requesting user's identity with `?include=user`.

2. **Custom Fields** (`GET /evertimer/custom_fields.json`): the `TimeEntryCustomField` records visible to the requesting user, narrowed to the twelve attributes EverTimer actually needs to render a custom-field input. This addresses limitations with the core Redmine API endpoint `/custom_fields.json`, which requires admin privileges and returns comprehensive details unnecessary for [EverTimer](https://chromewebstore.google.com/detail/evertimer/kjbdlnkafjlgnbmbeihkampliednpmgk).

Before you start
----------------

- **Check compatibility** in the table above. Redmine 7.0.1, 6.1.1 and 5.0.5 are tested; 4.1.1 is compatible at the API level only.
- **Enable the REST API.** The plugin requires `Enable REST web service` to be enabled in your Redmine Settings. To do so go to **Settings** > **API** and ensure that the **Enable REST web service** option is checked. You can find it at `https://your-redmine-domain/settings?tab=api`
![Enable REST web service](images/configure_redmine.png?raw=true)
- **No extra gems.** The plugin ships no `Gemfile`, so there is no `bundle install` step of its own.
- **Back up your database** before any migration: install, upgrade or rollback. See [Redmine backups](https://www.redmine.org/projects/redmine/wiki/RedmineBackupAndRestore).

Installation
------------

1. Clone the plugin into Redmine's `plugins` directory:
```bash
cd /path/to/redmine/plugins
git clone https://github.com/everlabs/evertimer_redmine_plugin.git
```
The plugin directory must be named `evertimer_redmine_plugin` — Redmine derives both the plugin identifier and the mirrored asset path (`public/plugin_assets/evertimer_redmine_plugin`) from the directory name.

2. Run the plugin's migrations from the Redmine root:
```bash
bundle exec rake redmine:plugins:migrate NAME=evertimer_redmine_plugin RAILS_ENV=production
```
The `NAME=` argument scopes the run to this plugin only, so other installed plugins are left alone. The migrations add a `time_entries (user_id, spent_on)` index used by the statistics endpoint.

3. Restart Redmine the way your deployment runs it:
   - Passenger: `touch tmp/restart.txt` in the Redmine root
   - systemd / Puma: `sudo systemctl restart <your-redmine-service>`
   - Docker: `docker restart <container>`

   Redmine mirrors the plugin's assets (`assets/javascripts`, `assets/stylesheets`, used by the settings screen) when it starts. On Redmine 6.0+ in production, if the plugin settings screen opens without its styles or scripts, run `bundle exec rake assets:precompile RAILS_ENV=production` and restart again.

4. Verify the installation:
   - **Administration** > **Plugins** lists **Evertimer plugin** 1.0.0.
   - The statistics endpoint answers with your API key:
```bash
curl -i -H "X-Redmine-API-Key: your_api_key" -H "Accept: application/json" \
  https://your-redmine-domain/evertimer/user_stats
```
   `200` with a JSON body means the plugin works. See **Troubleshooting** below for anything else.

### Docker (official `redmine` image)

Mount the plugin at `/usr/src/redmine/plugins/evertimer_redmine_plugin`:

```yaml
services:
  redmine:
    image: redmine:6.1
    volumes:
      - ./plugins/evertimer_redmine_plugin:/usr/src/redmine/plugins/evertimer_redmine_plugin
    environment:
      REDMINE_PLUGINS_MIGRATE: "1"
```

With `REDMINE_PLUGINS_MIGRATE` set, the image's entrypoint runs the plugin migrations when the container starts (only with the image's default command). Without it, migrate inside the running container and restart it:

```bash
docker exec -it <container> bundle exec rake redmine:plugins:migrate NAME=evertimer_redmine_plugin RAILS_ENV=production
docker restart <container>
```

Configuration
-------------

### Non-billable time

Non-billable classification is configured per Redmine instance under **Administration** > **Plugins** > **Evertimer plugin** > **Configure**. You can mark projects, trackers, issue statuses, time-tracking activities and custom-field values as non-billable. Until the settings are saved, all time counts as billable.

### The EverTimer extension

Each user connects the extension to Redmine once:

1. In Redmine, open **My account** (`https://your-redmine-domain/my/account`) and copy the **API access key** (click **Show** in the sidebar).
2. Open the [EverTimer](https://chromewebstore.google.com/detail/evertimer/kjbdlnkafjlgnbmbeihkampliednpmgk) extension. On first run it opens **Settings**. Enter the Redmine domain and the API key, then save.
3. The statistics circles (today, week, month, billable split) appear once the plugin responds.

The extension also works without the plugin. Tracking and submitting time are unaffected; the statistics panel shows "Install the plugin on your Redmine to unlock statistics" instead of figures.

Upgrading
---------

1. Back up your database.
2. Update the plugin directory, keeping its name `evertimer_redmine_plugin` (for example `git pull` inside it).
3. Run the migration command from **Installation**, step 2. Migrations that are already applied are skipped.
4. Restart Redmine (**Installation**, step 3).

### Uninstalling / rolling back

1. Roll the plugin's migrations back from the Redmine root — this drops the plugin's `time_entries (user_id, spent_on)` index and leaves no plugin rows behind in `schema_migrations`:
```bash
bundle exec rake redmine:plugins:migrate NAME=evertimer_redmine_plugin VERSION=0 RAILS_ENV=production
```
2. Remove the plugin directory (`#{RAILS_ROOT}/plugins/evertimer_redmine_plugin`) and its mirrored assets (`#{RAILS_ROOT}/public/plugin_assets/evertimer_redmine_plugin`).
3. Restart Redmine.

Run step 1 **before** removing the directory: the rake task needs the plugin's own migration files to know how to reverse them.

Note on pre-existing indexes: the migrations check for indexes by column, not by who created them. If `time_entries` already had a single-column `spent_on` index before you installed (stock Redmine has none), the install replaces it with the composite `(user_id, spent_on)` index, and `VERSION=0` removes it and does not put it back. The same goes for a composite `(user_id, spent_on)` index that already existed. If you had created one of these yourself, re-create it after uninstalling (for example `add_index :time_entries, :spent_on`).

Troubleshooting
---------------

| Symptom | Likely cause | What to do |
|---------|--------------|------------|
| Plugin not listed under **Administration** > **Plugins** | Redmine was not restarted, or the directory is not named `evertimer_redmine_plugin` | Rename the directory if needed and restart Redmine |
| `401` or `403` with an empty body from `/evertimer/user_stats` | **Enable REST web service** is off, or the API key is wrong | Enable it under **Settings** > **API**; re-copy the key from **My account** |
| `302` redirect to the login page | The request did not ask for JSON | Send `Accept: application/json` or use the `.json` suffix |
| `404` from `/evertimer/user_stats` | The plugin is not loaded | Check the plugin list and restart Redmine |
| `VERSION=0` rollback fails | The plugin directory was removed first | Put the directory back, roll back, then remove it |
| Extension shows "Install the plugin on your Redmine to unlock statistics" | Plugin not installed or not reachable, or the extension points at another Redmine | Run the `curl` check above against the domain entered in the extension |
| Settings screen shows unstyled lists or the custom-field picker does nothing | Plugin assets not mirrored or compiled | Restart Redmine; on 6.0+ in production also run `assets:precompile` |

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
- The plain ETag changes when the user's time entries change, when an issue those entries point at changes (so closing an issue or changing its tracker re-splits billable vs non-billable immediately), or when the plugin settings are saved. The `include=user` ETag additionally changes when the user's profile or email address changes, or when the instance's Gravatar settings change, so a stale name or avatar is never served behind a 304.
- **Known staleness classes:** editing *only* a time entry's custom-field value does not move the validator. `custom_values` carries no timestamp column, and Redmine saves custom values without touching the parent `time_entries` row, so there is nothing cheap to detect. If the plugin is configured with non-billable **custom-field** criteria, such an edit can be served from cache for up to the fragment lifetime (24 hours) or until anything else in the basis moves. Non-billable criteria based on projects, activities, trackers or issue statuses are not affected by that particular case — with two exceptions: deleting an issue whose time entries are reassigned or nullified, or deleting an activity and reassigning its time entries, moves them with Redmine's bulk `update_all`, which likewise does not touch the basis, so a tracker-, status- or activity-based split can also be served stale for the same window.

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

We welcome contributions! Please review our [contributing guidelines](CONTRIBUTING.md) before submitting pull requests or issues. Ensure you merge the latest changes from "upstream" before making a pull request. Participation is governed by our [Code of Conduct](CODE_OF_CONDUCT.md).

Security
--------

Found a security issue? Please don't open a public issue — see [SECURITY.md](SECURITY.md) for how to report it privately.

Copyright and Licensing
-----------------------

Copyright (C) 2025 Everlabs

This project is licensed under the **GNU General Public License, version 2** — the same license as Redmine itself. The plugin loads and extends Redmine's own classes, so GPLv2 is the license-compatible choice. Contributors retain the copyright of their contributions but must license them under the GPL for inclusion in the main repository.

The complete license text is in the [LICENSE](LICENSE) file.

License Summary
---------------

You can copy and paste the GPL license summary from below.

```
Copyright (C) 2025 Everlabs

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA.
```

Star History
------------

[![Star History Chart](https://api.star-history.com/svg?repos=everlabs/evertimer_redmine_plugin&type=Date)](https://star-history.com/#everlabs/evertimer_redmine_plugin&Date)

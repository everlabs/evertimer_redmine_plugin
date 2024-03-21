EverTimer Redmine plugin
========================
Extends the Capabilities of the EverTimer Chrome Extension

Compatibility
-------------

The plugin has been tested and is compatible with the following versions:

- Redmine v5.0.5, v4.1.1
- Ruby v3.1.3, v2.6.6
- Rails v6.1.7.2, v5.2.4.2

Features
--------

This plugin extends the capabilities of the [EverTimer](https://chromewebstore.google.com/detail/evertimer/kjbdlnkafjlgnbmbeihkampliednpmgk) Chrome extension by providing API endpoints for:

1. **User Statistics**: Returns a payload with the sum of TimeEntry hours for today, this week, and this month. It also includes billable hours based on the presence of a "Non-Billable" custom field or a "Non-billable" Enumeration Activity (time tracking).
    - **Endpoint**: `GET /evertimer/user_stats`
    - **Required Headers**: `"X-Redmine-API-Key": your_api_key` (Find your API key at `https://your-redmine-domain/my/api_key`)
    - **Example**: Fetch user statistics for time entries.
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

2. **Custom Fields**: Shows all TimeEntryCustomField records visible to the user, including fields `name`, `format`, `possible_values`, `regexp`, `min_length`, `max_length`, `is_required`, `default_value`, `multiple`, `format_store`. This addresses limitations with the existing Redmine API endpoint `/custom_fields.json`, which requires admin privileges and returns comprehensive details unnecessary for [EverTimer](https://chromewebstore.google.com/detail/evertimer/kjbdlnkafjlgnbmbeihkampliednpmgk).

3. **Statuses**: Provides all IssueStatus records with their `id`, `name`, and `position`, supplementing the Redmine API endpoint `/issue_statuses.json` that lacks the `position` value.

Configuration
-------------

The plugin requires `Enable REST web service` to be enabled in your Redmine Settings. To do so go to **Settings** > **API** and ensure that the **Enable REST web service** option is checked. You can find it at `https://your-redmine-domain/settings?tab=api`
![Enable REST web service](images/configure_redmine.png?raw=true)


Installation
------------

1. Copy your plugin directory into `#{RAILS_ROOT}/plugins`. If you are downloading the plugin directly from GitHub, you can do so by navigating to your plugin directory and using the following command:
```bash 
git clone https://github.com/everlabs/evertimer_redmine_plugin.git
```

2. After copying the plugin into the appropriate directory, restart Redmine to apply the changes.

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
Copyright 2024 by Everlabs

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

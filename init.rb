include NonBillableCustomFieldsHelper

Redmine::Plugin.register :evertimer_redmine_plugin do
  name 'Evertimer plugin'
  author 'Everlabs'
  description 'Extends the capabilities of the EverTimer Chrome extension'
  version '0.0.1'
  url 'https://github.com/everlabs/evertimer_redmine_plugin'
  author_url 'http://everlabs.com'

  settings default: {
    non_billable_projects: [],
    non_billable_trackers: [],
    non_billable_issue_statuses: [],
    non_billable_time_entry_activities: [],
    non_billable_custom_fields: {}
  }, partial: 'settings/settings'
end

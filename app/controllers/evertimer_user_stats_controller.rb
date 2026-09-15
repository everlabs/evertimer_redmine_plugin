# frozen_string_literal: true

class EvertimerUserStatsController < ApplicationController
  accept_api_auth :index, :custom_fields
  before_action :require_login

  # Don't skip session_expiration: it is Redmine's only server-side check of the session
  # token, so without it a logged-out or stolen session cookie would keep working here.

  # Redmine's start_of_week is 1..7, Monday first.
  DAY_SYMBOLS = %i[monday tuesday wednesday thursday friday saturday sunday].freeze

  WHITELISTED_CUSTOM_FIELD_ATTRIBUTES = %w[
    id
    name
    description
    field_format
    format_store
    possible_values
    multiple
    min_length
    max_length
    regexp
    is_required
    default_value
  ].freeze

  def index
    with_user = params[:include] == 'user'

    ranges    = stats_date_ranges
    scan_from = [ranges[:week].begin, ranges[:month].begin].min
    scan_to   = [ranges[:week].end, ranges[:month].end].max

    key_basis = stats_key_basis(ranges, scan_from, scan_to)

    # The user payload isn't cached, so profile edits must change the ETag instead.
    # The 'user' marker keeps the two variants' ETags distinct.
    etag_basis = with_user ? key_basis + [User.current.updated_on&.iso8601(6), 'user'] : key_basis

    return unless stale?(etag: etag_basis)

    stats_json = read_fragment(key_basis)
    unless stats_json
      stats_json = compute_stats_json(ranges, scan_from, scan_to)
      # The key rotates daily, and Rails' default FileStore never evicts entries without an expiry.
      write_fragment(key_basis, stats_json, expires_in: 24.hours)
    end

    if with_user
      payload = JSON.parse(stats_json)
      payload['user'] = user_payload
      render json: payload, status: :ok
    else
      render body: stats_json, content_type: 'application/json'
    end
  end

  def custom_fields
    render json: TimeEntryCustomField.visible.sorted.distinct.as_json(only: WHITELISTED_CUSTOM_FIELD_ATTRIBUTES),
           status: :ok
  end

  private

  # Core prefers the session cookie over the API key on non-API-format requests, and the
  # extension sends both, so the key must win. An invalid key yields no user (401) rather
  # than falling back to the cookie's account. X-Redmine-Switch-User is ignored on this path.
  def find_current_user
    if !api_request? && session[:user_id] && Setting.rest_api_enabled? && accept_api_auth? &&
       (key = api_key_from_request)
      User.find_by_api_key(key)
    else
      super
    end
  end

  # Deliberately excludes the API key and email.
  def user_payload
    user = User.current

    payload = {
      'id' => user.id,
      'firstname' => user.firstname,
      'lastname' => user.lastname
    }

    # Mirrors core's users API. Goes through `helpers` because gravatar_url calls the view helper `h`.
    if user.mail.present? && Setting.gravatar_enabled?
      payload['avatar_url'] =
        helpers.gravatar_url(user.mail, {:rating => nil, :size => nil, :default => Setting.gravatar_default})
    end

    payload
  end

  def stats_date_ranges
    user_today = User.current.today

    start_of_week = Setting.start_of_week
    start_of_week = l(:general_first_day_of_week, :default => '1') if start_of_week.blank?

    {
      today: user_today,
      week: user_today.all_week(DAY_SYMBOLS[(start_of_week.to_i - 1) % 7]),
      month: user_today.all_month
    }
  end

  # Cache key and ETag basis. MAX/COUNT over time entries catch edits and deletions;
  # MAX(issues.updated_on) catches tracker/status changes that move the billable split.
  # Custom-value-only edits aren't detected (no timestamp), which expires_in bounds.
  def stats_key_basis(ranges, scan_from, scan_to)
    entries_table = TimeEntry.table_name
    issues_table  = Issue.table_name

    max_updated_on, entries_count, max_issue_updated_on =
      TimeEntry
        .where(user_id: User.current.id, spent_on: scan_from..scan_to)
        .joins("LEFT OUTER JOIN #{issues_table} ON #{issues_table}.id = #{entries_table}.issue_id")
        .pluck(
          Arel.sql("MAX(#{entries_table}.updated_on)"),
          Arel.sql('COUNT(*)'),
          Arel.sql("MAX(#{issues_table}.updated_on)")
        )
        .first

    settings_stamp = Setting.find_by(name: 'plugin_evertimer_redmine_plugin')&.updated_on&.iso8601(6) || 'unsaved'

    # SQLite returns MAX() as a raw String, which is kept as is.
    max_updated_on = max_updated_on.iso8601(6) if max_updated_on.respond_to?(:iso8601)
    max_issue_updated_on = max_issue_updated_on.iso8601(6) if max_issue_updated_on.respond_to?(:iso8601)

    [
      User.current.id,
      ranges[:today].iso8601,
      ranges[:week].begin.iso8601,
      ranges[:week].end.iso8601,
      ranges[:month].begin.iso8601,
      ranges[:month].end.iso8601,
      max_updated_on,
      entries_count,
      settings_stamp,
      max_issue_updated_on
    ]
  end

  def compute_stats_json(ranges, scan_from, scan_to)
    table = TimeEntry.table_name

    # The predicate is already sanitized and may contain '?' inside quoted values, which
    # breaks sanitize_sql_array's placeholder count, so it is spliced in afterwards.
    billable_marker = '__EVERTIMER_BILLABLE__'

    sql = TimeEntry.sanitize_sql_array(
      [
        <<~SQL,
          SELECT
            SUM(CASE WHEN #{table}.spent_on = ? THEN #{table}.hours END) AS today,
            SUM(CASE WHEN #{table}.spent_on BETWEEN ? AND ? THEN #{table}.hours END) AS this_week,
            SUM(CASE WHEN #{table}.spent_on BETWEEN ? AND ? THEN #{table}.hours END) AS this_month,
            SUM(CASE WHEN #{table}.spent_on = ? AND #{billable_marker} THEN #{table}.hours END) AS today_billable,
            SUM(CASE WHEN #{table}.spent_on BETWEEN ? AND ? AND #{billable_marker} THEN #{table}.hours END) AS this_week_billable,
            SUM(CASE WHEN #{table}.spent_on BETWEEN ? AND ? AND #{billable_marker} THEN #{table}.hours END) AS this_month_billable
          FROM #{table}
          WHERE #{table}.user_id = ? AND #{table}.spent_on BETWEEN ? AND ?
        SQL
        ranges[:today],
        ranges[:week].begin, ranges[:week].end,
        ranges[:month].begin, ranges[:month].end,
        ranges[:today],
        ranges[:week].begin, ranges[:week].end,
        ranges[:month].begin, ranges[:month].end,
        User.current.id,
        scan_from, scan_to
      ]
    )

    # Block form: a String replacement would interpret backslashes in custom-field values.
    billable = "NOT (#{non_billable_predicate_sql})"
    sql = sql.gsub(billable_marker) { billable }

    row = TimeEntry.connection.select_one(sql) || {}

    {
      today: stats_value(row['today']),
      this_week: stats_value(row['this_week']),
      this_month: stats_value(row['this_month']),
      today_billable: stats_value(row['today_billable']),
      this_week_billable: stats_value(row['this_week_billable']),
      this_month_billable: stats_value(row['this_month_billable'])
    }.to_json
  end

  def stats_value(value)
    value.nil? ? 0.0 : value.to_f
  end

  # EXISTS rather than a LEFT JOIN, so entries without an issue don't evaluate to NULL.
  def non_billable_predicate_sql
    settings = Setting.plugin_evertimer_redmine_plugin || {}
    table = TimeEntry.table_name
    criteria = []

    project_ids = non_billable_ids(settings['non_billable_projects'])
    if project_ids.any?
      criteria << TimeEntry.sanitize_sql_array(["#{table}.project_id IN (?)", project_ids])
    end

    activity_ids = non_billable_ids(settings['non_billable_time_entry_activities'])
    if activity_ids.any?
      criteria << TimeEntry.sanitize_sql_array(["#{table}.activity_id IN (?)", activity_ids])
    end

    tracker_ids = non_billable_ids(settings['non_billable_trackers'])
    if tracker_ids.any?
      criteria << TimeEntry.sanitize_sql_array(
        ["EXISTS (SELECT 1 FROM #{Issue.table_name} nb_issues " \
         "WHERE nb_issues.id = #{table}.issue_id AND nb_issues.tracker_id IN (?))", tracker_ids]
      )
    end

    status_ids = non_billable_ids(settings['non_billable_issue_statuses'])
    if status_ids.any?
      criteria << TimeEntry.sanitize_sql_array(
        ["EXISTS (SELECT 1 FROM #{Issue.table_name} nb_issues " \
         "WHERE nb_issues.id = #{table}.issue_id AND nb_issues.status_id IN (?))", status_ids]
      )
    end

    custom_fields = settings['non_billable_custom_fields']
    if custom_fields.is_a?(Hash)
      custom_fields.each do |field_id, value|
        values = Array(value).reject(&:blank?)
        next if field_id.blank? || values.empty?

        criteria << TimeEntry.sanitize_sql_array(
          ["EXISTS (SELECT 1 FROM #{CustomValue.table_name} nb_values " \
           "WHERE nb_values.customized_type = 'TimeEntry' " \
           "AND nb_values.customized_id = #{table}.id " \
           "AND nb_values.custom_field_id = ? AND nb_values.value IN (?))",
           field_id.to_i, values]
        )
      end
    end

    criteria.any? ? criteria.join(' OR ') : '1=0'
  end

  def non_billable_ids(value)
    Array(value).reject(&:blank?).map(&:to_i)
  end
end

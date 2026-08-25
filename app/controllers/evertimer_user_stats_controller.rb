# frozen_string_literal: true

class EvertimerUserStatsController < ApplicationController
  accept_api_auth :index, :custom_fields
  before_action :require_login
  skip_before_action :session_expiration

  # Redmine stores start_of_week as 1..7 (monday..sunday), both in Setting.start_of_week
  # and in the :general_first_day_of_week locale key (see application_helper.rb:1634-1638).
  DAY_SYMBOLS = %i[monday tuesday wednesday thursday friday saturday sunday].freeze

  def index
    ranges    = stats_date_ranges
    scan_from = [ranges[:week].begin, ranges[:month].begin].min
    scan_to   = [ranges[:week].end, ranges[:month].end].max

    key_basis = stats_key_basis(ranges, scan_from, scan_to)

    # fresh_when (inside stale?) answers 304 with an empty body itself, before any
    # fragment lookup or stats SQL runs (actionpack conditional_get.rb:121).
    return unless stale?(etag: key_basis)

    stats_json = read_fragment(key_basis)
    unless stats_json
      stats_json = compute_stats_json(ranges, scan_from, scan_to)
      # write_fragment requires a String (it calls #to_str) and no-ops safely when
      # perform_caching is false.
      write_fragment(key_basis, stats_json)
    end

    # Passthrough render keeps cached and freshly computed responses byte-identical.
    render body: stats_json, content_type: 'application/json'
  end

  def custom_fields
    render json: TimeEntryCustomField.visible.sorted.distinct, status: :ok
  end

  private

  # Date ranges follow the requesting user's time zone and Redmine's start-of-week
  # setting, falling back to the locale default when the setting is blank.
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

  # Cache-key / ETag basis. The date-window components make the key change at the
  # user's midnight (and whenever the week start or time zone moves the window);
  # MAX(updated_on) catches edits, COUNT(*) catches deletions.
  def stats_key_basis(ranges, scan_from, scan_to)
    max_updated_on, entries_count =
      TimeEntry
        .where(user_id: User.current.id, spent_on: scan_from..scan_to)
        .pluck(Arel.sql('MAX(updated_on), COUNT(*)'))
        .first

    settings_stamp = Setting.find_by(name: 'plugin_evertimer_redmine_plugin')&.updated_on || 'unsaved'

    [
      User.current.id,
      ranges[:today].iso8601,
      ranges[:week].begin.iso8601,
      ranges[:week].end.iso8601,
      ranges[:month].begin.iso8601,
      ranges[:month].end.iso8601,
      max_updated_on,
      entries_count,
      settings_stamp
    ]
  end

  # One conditional-aggregation pass over the scan window returns all six figures.
  def compute_stats_json(ranges, scan_from, scan_to)
    table = TimeEntry.table_name
    billable = "NOT (#{non_billable_predicate_sql})"

    sql = TimeEntry.sanitize_sql_array(
      [
        <<~SQL,
          SELECT
            SUM(CASE WHEN #{table}.spent_on = ? THEN #{table}.hours END) AS today,
            SUM(CASE WHEN #{table}.spent_on BETWEEN ? AND ? THEN #{table}.hours END) AS this_week,
            SUM(CASE WHEN #{table}.spent_on BETWEEN ? AND ? THEN #{table}.hours END) AS this_month,
            SUM(CASE WHEN #{table}.spent_on = ? AND #{billable} THEN #{table}.hours END) AS today_billable,
            SUM(CASE WHEN #{table}.spent_on BETWEEN ? AND ? AND #{billable} THEN #{table}.hours END) AS this_week_billable,
            SUM(CASE WHEN #{table}.spent_on BETWEEN ? AND ? AND #{billable} THEN #{table}.hours END) AS this_month_billable
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

    row = TimeEntry.connection.select_one(sql) || {}

    # An empty period sums to SQL NULL; today's implementation renders 0.0 there
    # (TimeEntry#sum on a float column), so the mapping keeps float semantics.
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

  # SQL predicate matching the time entries the admin configured as non-billable.
  # Every settings-derived value is bound, never interpolated. Issue- and
  # custom-field-based criteria use EXISTS so the predicate stays two-valued:
  # a LEFT JOIN would yield NULL for issue-less entries and misclassify them.
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
        # A blank configured value must match nothing at all.
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

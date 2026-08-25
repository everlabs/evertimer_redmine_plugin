# frozen_string_literal: true

class EvertimerUserStatsController < ApplicationController
  accept_api_auth :index, :custom_fields
  before_action :require_login
  skip_before_action :session_expiration

  # Redmine stores start_of_week as 1..7 (monday..sunday), both in Setting.start_of_week
  # and in the :general_first_day_of_week locale key (see application_helper.rb:1634-1638).
  DAY_SYMBOLS = %i[monday tuesday wednesday thursday friday saturday sunday].freeze

  # The only custom-field attributes the extension reads. Everything else on the
  # record is internal Redmine configuration (visibility, filtering, positioning)
  # that no client needs, so it stays out of the payload.
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

    # The user hash is never cached (it is appended per request), so its freshness
    # has to ride on the ETag instead: a profile edit moves User#updated_on and
    # busts only the include=user ETag. The literal marker keeps the two variants
    # of the same stats from ever colliding on one ETag value.
    etag_basis = with_user ? key_basis + [User.current.updated_on, 'user'] : key_basis

    # fresh_when (inside stale?) answers 304 with an empty body itself, before any
    # fragment lookup or stats SQL runs (actionpack conditional_get.rb:121).
    return unless stale?(etag: etag_basis)

    # The fragment key stays the stats-only basis in BOTH cases: the cache holds
    # the stats JSON and nothing else.
    stats_json = read_fragment(key_basis)
    unless stats_json
      stats_json = compute_stats_json(ranges, scan_from, scan_to)
      # write_fragment requires a String (it calls #to_str) and no-ops safely when
      # perform_caching is false.
      write_fragment(key_basis, stats_json)
    end

    if with_user
      # Parse/merge rather than string surgery: the six stats keys keep their order
      # (Ruby hashes are insertion-ordered) and "user" is appended last.
      payload = JSON.parse(stats_json)
      payload['user'] = user_payload
      render json: payload, status: :ok
    else
      # Passthrough render keeps cached and freshly computed responses byte-identical.
      render body: stats_json, content_type: 'application/json'
    end
  end

  def custom_fields
    # Same scope chain and same top-level-array shape as before; only the set of
    # serialized attributes narrows. possible_values (serialize) and format_store
    # (store) still come out as an array and a hash respectively.
    render json: TimeEntryCustomField.visible.sorted.distinct.as_json(only: WHITELISTED_CUSTOM_FIELD_ATTRIBUTES),
           status: :ok
  end

  private

  # Exactly the fields the extension stores for the signed-in user, under Redmine's
  # own names (users/show.api.rsb:2-12). The API credential is deliberately absent:
  # the caller already holds the key it authenticated with, so echoing it would only
  # widen the blast radius of a leaked response.
  def user_payload
    user = User.current

    payload = {
      'id' => user.id,
      'firstname' => user.firstname,
      'lastname' => user.lastname
    }

    # Same guard and same helper call as core's users API (users/show.api.rsb:12) —
    # key absent (not null) when the user has no mail or Gravatar is off, which the
    # extension's default-avatar fallback already covers.
    # Called through `helpers` because gravatar_url internally uses the view helper
    # `h`, which a bare controller instance does not respond to.
    if user.mail.present? && Setting.gravatar_enabled?
      payload['avatar_url'] =
        helpers.gravatar_url(user.mail, {:rating => nil, :size => nil, :default => Setting.gravatar_default})
    end

    payload
  end

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

    # The billable predicate is already fully sanitized by non_billable_predicate_sql
    # (every settings-derived value is bound there), so it must NOT be interpolated into
    # the array handed to the outer sanitize pass. replace_bind_variables validates arity
    # with statement.count("?") (activerecord sanitization.rb), and that count includes
    # '?' characters sitting inside quoted string literals. An admin-configured
    # custom-field value such as 'Billable?' would therefore inflate the placeholder
    # count and raise ActiveRecord::PreparedStatementInvalid on every cache-miss request.
    # Sanitize the skeleton against a sentinel first, then splice the predicate in.
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

    # Block form on purpose: a String replacement argument would interpret backslash
    # escapes (\\0, \\1, \\\\) that can legitimately occur inside a quoted custom-field
    # value, corrupting the spliced predicate.
    billable = "NOT (#{non_billable_predicate_sql})"
    sql = sql.gsub(billable_marker) { billable }

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

# frozen_string_literal: true

class EvertimerUserStatsController < ApplicationController
  accept_api_auth :index, :custom_fields
  skip_before_action :session_expiration, :set_localization

  def index
    data = {
      today: calculate_hours(:today),
      this_week: calculate_hours(:this_week),
      this_month: calculate_hours(:this_month)
    }

    data.merge!(
      today_billable: calculate_hours(:today, billable: true),
      this_week_billable: calculate_hours(:this_week, billable: true),
      this_month_billable: calculate_hours(:this_month, billable: true)
    )

    render json: data, status: :ok
  end

  def custom_fields
    render json: TimeEntryCustomField.visible.sorted.distinct, status: :ok
  end

  private

  def calculate_hours(period, billable: false)
    date_range = calculate_date_range(period)
    time_entries = TimeEntry.where(user: User.current, spent_on: date_range)
    time_entries = non_billable_time_entries(time_entries) if billable

    time_entries.sum(:hours)
  end

  def calculate_date_range(period)
    case period
    when :today
      Date.current
    when :this_week
      Date.current.all_week
    when :this_month
      Date.current.all_month
    end
  end

  def non_billable_time_entries(query)
    time_entries = TimeEntry.arel_table
    subquery_managers = []

    # 1. Non-billable by project
    project_ids = Setting.plugin_evertimer_redmine_plugin['non_billable_projects']&.compact_blank&.map(&:to_i)
    if project_ids&.any?
      subquery_managers << TimeEntry
        .where(project_id: project_ids)
        .select(:id)
        .arel
    end

    # 2. Non-billable by activity
    activity_ids = Setting.plugin_evertimer_redmine_plugin['non_billable_time_entry_activities']&.compact_blank&.map(&:to_i)
    if activity_ids&.any?
      subquery_managers << TimeEntry
        .where(activity_id: activity_ids)
        .select(:id)
        .arel
    end

    # 3. Non-billable by issue tracker
    tracker_ids = Setting.plugin_evertimer_redmine_plugin['non_billable_trackers']&.compact_blank&.map(&:to_i)
    if tracker_ids&.any?
      subquery_managers << TimeEntry
        .joins(:issue)
        .where(issues: {tracker_id: tracker_ids})
        .select(:id)
        .arel
    end

    # 4. Non-billable by issue status
    status_ids = Setting.plugin_evertimer_redmine_plugin['non_billable_issue_statuses']&.compact_blank&.map(&:to_i)
    if status_ids&.any?
      subquery_managers << TimeEntry
        .joins(:issue)
        .where(issues: {status_id: status_ids})
        .select(:id)
        .arel
    end

    # 5. Non-billable by custom fields
    if Setting.plugin_evertimer_redmine_plugin['non_billable_custom_fields']&.compact_blank&.any?
      Setting.plugin_evertimer_redmine_plugin['non_billable_custom_fields'].each do |field_id, value|
        subquery_managers << TimeEntry
          .joins(:custom_values)
          .where(custom_values: {customized_type: 'TimeEntry',
                                 custom_field_id: field_id.to_i,
                                 value: value})
          .select(:id)
          .arel
      end
    end

    # Combine all subqueries with UNION using Arel
    if subquery_managers.any?
      union_expression = subquery_managers.shift.ast

      subquery_managers.each do |manager|
        union_expression = Arel::Nodes::Union.new(union_expression, manager.ast)
      end

      union_group = Arel::Nodes::Grouping.new(union_expression)

      # Exclude time entries whose IDs are in the UNION result
      query = query.where.not(time_entries[:id].in(union_group))
    end

    query
  end
end

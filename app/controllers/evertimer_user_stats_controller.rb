# frozen_string_literal: true

class EvertimerUserStatsController < ApplicationController
  accept_api_auth :index
  skip_before_action :session_expiration, :set_localization

  def index
    data = {
      today: calculate_hours(:today),
      this_week: calculate_hours(:this_week),
      this_month: calculate_hours(:this_month)
    }

    if billable_available?
      data.merge!(
        today_billable: calculate_hours(:today, billable: true),
        this_week_billable: calculate_hours(:this_week, billable: true),
        this_month_billable: calculate_hours(:this_month, billable: true)
      )
    end

    render json: data, status: :ok
  end

  private

  def calculate_hours(period, billable: false)
    date_range = calculate_date_range(period)
    time_entries = time_entries_for_range(date_range)
    time_entries = filter_billable(time_entries) if billable
    sum_of_hours(time_entries)
  end

  def calculate_date_range(period)
    case period
    when :today
      DateTime.current
    when :this_week
      DateTime.current.beginning_of_week..
    when :this_month
      DateTime.current.beginning_of_month..
    end
  end

  def time_entries_for_range(date_range)
    TimeEntry.where(user: User.current, spent_on: date_range)
  end

  def filter_billable(time_entries)
    return time_entries unless billable_available?

    filtered_entries = time_entries

    if @custom_field_billable
      filtered_entries = filtered_entries
                           .joins(:custom_values)
                           .where(custom_values: { custom_field_id: @custom_field_billable.id, value: '0' })
    end

    filtered_entries = filtered_entries.where.not(activity_id: @activity_billable.id) if @activity_billable

    filtered_entries
  end

  def sum_of_hours(time_entries)
    time_entries.sum(:hours)
  end

  def billable_available?
    @custom_field_billable = TimeEntryCustomField.find_by(name: 'Non-Billable', type: 'TimeEntryCustomField', visible: true)
    @activity_billable = Enumeration.find_by(name: "Non-billable", type: "TimeEntryActivity", active: true)

    @custom_field_billable || @activity_billable
  end
end



respond_to do |format|
  format.html do
    @entry_count = scope.count
    @entry_pages = Paginator.new @entry_count, per_page_option, params['page']
    @entries = scope.offset(@entry_pages.offset).limit(@entry_pages.per_page).to_a

    render :layout => !request.xhr?
  end
  format.api do
    @entry_count = scope.count
    @offset, @limit = api_offset_and_limit
    @entries = scope.offset(@offset).limit(@limit).preload(:custom_values => :custom_field).to_a
  end
  format.atom do
    entries = scope.limit(Setting.feeds_limit.to_i).reorder("#{TimeEntry.table_name}.created_on DESC").to_a
    render_feed(entries, :title => l(:label_spent_time))
  end
  format.csv do
    # Export all entries
    @entries = scope.to_a
    send_data(query_to_csv(@entries, @query, params), :type => 'text/csv; header=present', :filename => 'timelog.csv')
  end
end

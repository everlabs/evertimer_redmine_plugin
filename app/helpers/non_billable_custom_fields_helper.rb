# frozen_string_literal: true

module NonBillableCustomFieldsHelper
  def render_custom_field_row(custom_field_value, is_template: false)
    field_id = "time_entry_custom_field_values_#{custom_field_value.custom_field_id}"
    row_data = { id: custom_field_value.custom_field_id }
    # Template rows are hidden, so custom_fields.js runs this toolbar script on the cloned row instead.
    if custom_field_value.custom_field.full_text_formatting? && is_template
      row_data[:wikitoolbar] = wikitoolbar_for(field_id)
    end

    result = content_tag(:tr, id: "template_#{custom_field_value.custom_field_id}", data: row_data) do
      concat content_tag(:td, TimelogController.helpers.custom_field_label_tag(:time_entry, custom_field_value), class: "field-name")
      concat content_tag(:td, TimelogController.helpers.custom_field_tag(:time_entry, custom_field_value), class: "field-value")
      concat content_tag(:td, link_to(l(:button_delete), '#', class: 'delete-custom-field icon-only icon-del', title: l(:button_delete)), class: "buttons" )
    end

    if custom_field_value.custom_field.full_text_formatting? && !is_template
      result += wikitoolbar_for("time_entry_custom_field_values_#{custom_field_value.custom_field_id}")
    end

    result
  end

  def selected_non_billable_custom_fields
    selected_option_ids = Setting.plugin_evertimer_redmine_plugin['non_billable_custom_fields']&.keys&.map(&:to_i) || []

    all_custom_field_values.select { |el| el.custom_field.id.in?(selected_option_ids) }.map do |cfv|
      val = Setting.plugin_evertimer_redmine_plugin['non_billable_custom_fields'][cfv.custom_field.id.to_s]
      # Not reject! (it would mutate Redmine's process-wide settings cache), nor compact_blank (Rails 6.1+).
      val = val.reject(&:blank?) if val.is_a?(Array)
      cfv.value = val
      cfv
    end
  end

  def available_non_billable_custom_fields
    selected_option_ids = Setting.plugin_evertimer_redmine_plugin['non_billable_custom_fields']&.keys&.map(&:to_i) || []

    all_custom_field_values.reject { |el| el.custom_field_id.in?(selected_option_ids) }
  end

  # Attachment custom fields are not supported.
  def all_custom_field_values
    @all_custom_field_values ||= TimeEntry.new.custom_field_values.reject { |el| el.custom_field.field_format == 'attachment' }
  end
end

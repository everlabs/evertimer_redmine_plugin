# frozen_string_literal: true

# Provides helper methods for managing non-billable custom fields within plugin settings.
module NonBillableCustomFieldsHelper
  # Renders an HTML table row for a given custom field value.
  # This row includes the custom field's name, its value input, and a delete button.
  # @param custom_field_value [CustomFieldValue] The value object associated with the custom field.
  # @param is_template [Boolean] Flag to indicate if the row should be rendered for a template.
  #                              Templates are used for dynamically adding new fields via JavaScript.
  def render_custom_field_row(custom_field_value, is_template: false)
    result = content_tag(:tr, id: "template_#{custom_field_value.custom_field_id}", data: { id: custom_field_value.custom_field_id }) do
      # Custom field label
      concat content_tag(:td, TimelogController.helpers.custom_field_label_tag(:time_entry, custom_field_value), class: "field-name")
      # Custom field input
      concat content_tag(:td, TimelogController.helpers.custom_field_tag(:time_entry, custom_field_value), class: "field-value")
      # Delete button
      concat content_tag(:td, link_to('Delete', '#', class: 'delete-custom-field icon-only icon-del', title: 'Delete'), class: "buttons" )
    end

    # Optionally append a wiki toolbar for fields with full text formatting enabled.
    # The toolbar is not added for template rows.
    if custom_field_value.custom_field.full_text_formatting? && !is_template
      result += wikitoolbar_for("time_entry_custom_field_values_#{custom_field_value.custom_field_id}")
    end

    result
  end

  # Selects and prepares custom fields that have been marked as non-billable by the user.
  # @return [Array<CustomFieldValue>] The selected custom field values, prepared with user-configured values.
  def selected_non_billable_custom_fields
    selected_option_ids = Setting.plugin_evertimer_redmine_plugin['non_billable_custom_fields']&.keys&.map(&:to_i) || []

    all_custom_field_values.select { |el| el.custom_field.id.in?(selected_option_ids) }.map do |cfv|
      val = Setting.plugin_evertimer_redmine_plugin['non_billable_custom_fields'][cfv.custom_field.id.to_s]
      val.compact_blank! if val.is_a?(Array)
      cfv.value = val
      cfv
    end
  end

  # Gathers available custom fields that have not been selected by the user.
  # @return [Array<CustomFieldValue>] Custom fields available for selection.
  def available_non_billable_custom_fields
    selected_option_ids = Setting.plugin_evertimer_redmine_plugin['non_billable_custom_fields']&.keys&.map(&:to_i) || []

    all_custom_field_values.reject { |el| el.custom_field_id.in?(selected_option_ids) }
  end

  # Fetches all custom field values, excluding those of type 'attachment' (they are not supported yet)
  # @return [Array<CustomFieldValue>] All custom field values, filtered by type.
  def all_custom_field_values
    @all_custom_field_values ||= TimeEntry.new.custom_field_values.reject { |el| el.custom_field.field_format == 'attachment' }
  end
end

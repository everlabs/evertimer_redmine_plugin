$(document).ready(() => {
    // This changes elements' name attribute to fit the non-billable custom fields structure for plugin's setting.
    $('[name*="time_entry[custom_field_values]"]').each(function() {
        let originalName = $(this).attr('name');
        let newName = originalName.replace('time_entry[custom_field_values]', 'settings[non_billable_custom_fields]');
        $(this).attr('name', newName);
    });

    // When an available custom field is selected from the dropdown,
    // add its corresponding row to the selected custom fields table.
    $('#available_custom_fields').change(function(event) {
        const selectedFieldId = $(this).val();

        if (!selectedFieldId) return;

        const templateContent = $('#template_' + selectedFieldId)[0].outerHTML;
        $('#customFieldsTable tbody').append(templateContent);
        $(this).find(':selected').remove(); // Remove the selected option from the dropdown to prevent duplicate selections.
        $(this).val(''); // Reset dropdown
    });

    // Before form submission, remove the custom field templates to prevent their values from being submitted.
    $('form').on('submit', () => {
        $('#customFieldTemplates').remove();
    });

    // Handle the removal of a selected custom field row from the table.
    // This includes re-adding the option to the dropdown for potential re-selection.
    $('#customFieldsTable').on('click', 'a.delete-custom-field', function(e){
        e.preventDefault();

        const confirmationMessage = $('meta[name="custom-field-delete-confirmation"]').attr('content');
        if (!confirm(confirmationMessage)) return;

        const row = $(this).closest('tr');
        const optionName = row.find('.field-name').text();
        const optionId = row.data('id');
        $('#available_custom_fields').append(`<option value="${optionId}">${optionName}</option>`);
        row.remove();
    });

});
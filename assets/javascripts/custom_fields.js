$(document).ready(() => {
    // Core renders these as time entry fields; rename them into the plugin's settings params.
    $('[name*="time_entry[custom_field_values]"]').each(function() {
        let originalName = $(this).attr('name');
        let newName = originalName.replace('time_entry[custom_field_values]', 'settings[non_billable_custom_fields]');
        $(this).attr('name', newName);
    });

    $('#available_custom_fields').change(function(event) {
        const selectedFieldId = $(this).val();

        if (!selectedFieldId) return;

        const tpl = $('#template_' + selectedFieldId);
        if (!tpl.length) return;
        const row = tpl.first().clone();
        $('#customFieldsTable tbody').append(row);

        // The table precedes the hidden templates, so the toolbar script's getElementById finds this clone.
        const toolbarScript = row.attr('data-wikitoolbar');
        if (toolbarScript) {
            row.removeAttr('data-wikitoolbar');
            row.find('td.field-value').append(toolbarScript);
        }
        $(this).find(':selected').remove();
        $(this).val('');
    });

    // Keep the template inputs out of the submitted settings.
    $('form').on('submit', () => {
        $('#customFieldTemplates').remove();
    });

    $('#customFieldsTable').on('click', 'a.delete-custom-field', function(e){
        e.preventDefault();

        const confirmationMessage = $('meta[name="custom-field-delete-confirmation"]').attr('content');
        if (!confirm(confirmationMessage)) return;

        const row = $(this).closest('tr');
        const optionName = row.find('.field-name').text();
        const optionId = row.data('id');
        // DOM APIs, not an HTML string: optionName is decoded text and must not be parsed as markup.
        $('#available_custom_fields').append($('<option>').val(optionId).text(optionName));
        row.remove();
    });

});

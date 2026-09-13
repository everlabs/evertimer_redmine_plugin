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

        const tpl = $('#template_' + selectedFieldId);
        if (!tpl.length) return;
        const row = tpl.first().clone();
        $('#customFieldsTable tbody').append(row);

        // Full-text-formatting fields: run the wikitoolbar_for script the template row carries, the way a
        // server-rendered row runs it inline. The table precedes the hidden templates, so its
        // getElementById resolves to this clone's textarea. Other field types carry no such attribute.
        const toolbarScript = row.attr('data-wikitoolbar');
        if (toolbarScript) {
            row.removeAttr('data-wikitoolbar');
            row.find('td.field-value').append(toolbarScript);
        }
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
        // Built through DOM APIs, not an HTML string: optionName comes from .text(), i.e.
        // already-decoded text. Interpolating it back into markup would re-inject a custom
        // field named e.g. `<img src=x onerror=...>` as live HTML, undoing the escaping
        // that options_for_select gives the server-rendered dropdown. .val()/.text() keep
        // both values as data.
        $('#available_custom_fields').append($('<option>').val(optionId).text(optionName));
        row.remove();
    });

});
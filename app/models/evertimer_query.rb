class EvertimerQuery < Query
  def initialize(attributes=nil, *args)
    self.queried_class = attributes&.dig(:queried_class)
    super attributes
  end

  def available_columns
    @available_columns ||= self.class.available_columns.dup + dynamic_columns_for_queried_class
  end

  def columns
    return [] if available_columns.empty? || column_names.nil?

    # preserve the column_names order
    cols = column_names.collect do |name|
      available_columns.find {|col| col.name == name}
    end.compact
    available_columns.select(&:frozen?) | cols
  end

  def column_names=(names)
    if names
      names = names.select {|n| !n.blank?}
      names = available_inline_columns.map(&:name) | names if names.delete(:all_inline)
      names = nil if names.sort == default_columns_names.sort
    end
    write_attribute(:column_names, names)
  end

  def queried_table_name
    @queried_table_name ||= queried_class.table_name
  end

  private

  def dynamic_columns_for_queried_class
    return [] unless queried_class

    items = queried_class.select(:id, :name)
    have_position = false

    if items.take.respond_to?(:position)
      have_position = true
      items = items.select(:position)
    end

    items.map do |item|
      properties = item_properties(item, have_position)
      QueryColumn.new(item.id.to_s, sortable: properties[:sortable], caption: item.name, default_order: properties[:default_order])
    end
  end

  def item_properties(item, have_position = false)
    properties = {}
    if have_position
      properties[:sortable] = "#{queried_table_name}.position"
      properties[:default_order] = item.position
    end
    properties
  end
end

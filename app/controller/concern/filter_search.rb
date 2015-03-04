module FilterSearch
  extend ActiveSupport::Concern
 
  included do
    before_action :index, only:  [:new, :create, :edit, :update]
  end
  
  TRUE_VALUES = [true, 'true', 'TRUE']

  def filter_search

    parameters      = []
    model_sym       = params[:controller].singularize.titlecase.gsub(" ","").downcase.to_sym
    model           = params[:controller].singularize.titlecase.gsub(" ","").constantize
    column_name     = model.column_names.dup
    column_type     = model.column_types
    remove_column  = (model.respond_to? :remove_column)   ? model.remove_column    : []
    include_has_many= (model.respond_to? :include_has_many) ? model.include_has_many  : []

    column_name.delete_if {|d| remove_column.include? d.to_sym }

    # belongs_to
    column_name.each      { |x| parameters << [(model.human_attribute_name x),x,{"data-tipo" => column_type[x].type}] }

    # has_many or has_one
    model.reflections.each do |hash_model, active_record|
      if (active_record.macro.eql?(:has_many) or active_record.macro.eql?(:has_one)) and include_has_many.include?(hash_model)
        class_has_many = hash_model.to_s.singularize.camelize.constantize
        name_input     = class_has_many.to_s.tableize if active_record.macro.eql?(:has_many)
        name_input     = hash_model.to_s if active_record.macro.eql?(:has_one)

        parameters     << [(class_has_many.model_name.human), name_input,{"data-tipo" => 'has_many'}]
      end
    end
    
    population       = ['']
    model_arel        = model.arel_table
    model_arel_array  = []

    if params["search"].present?
      params["search"].each do |k,v|
        # belongs_to e columns
        if (column_name.include? v["column"]) and v["column"].present? and v["value"].present?
          cul = v["column"]
          val = v["value"]

          if column_type[cul].type == :boolean
            model_arel_array << model_arel[ cul.to_sym ].eq( (TRUE_VALUES.include?(val.downcase) ? true : false)  ).to_sql
          elsif column_type[cul].type == :string
            model_arel_array << model_arel[ cul.to_sym ].matches( "%%#{val}%%" ).to_sql
          else
            model_arel_array << model_arel[ cul.to_sym ].eq( val  ).to_sql
          end
 
          population << {"key" => v["column"], "value" => v["value"], "tipo" => column_type[cul].type}

        # has_many
        elsif not column_name.include?(v["column"]) and validate_association(model,v["column"])
          model_has_many   = v["column"].singularize.camelize.constantize.arel_table
          model_arel_array << model_has_many[:id].eq( v["value"] ).to_sql

          population << {"key" => v["column"], "value" => v["value"], "tipo" => 'has_many'}
        end
      end
    else
      population = ['']
    end

   OpenStruct.new(parameter: parameters, condition: model_arel_array.join(" and "), population: population)
  end

  def filter_model
    @object           = []
    model_controller  = params[:controller].singularize.camelize.constantize
    busca             = params["column"]
    
    # model = model_controller.reflections[model_reflection.to_sym].options[:class_name]
    # model = mode.constantize if model.present?
    if busca.last(3).eql?('_id')
      if model_controller.reflections[busca.first(-3).to_sym].try(:options).present?
        model = model_controller.reflections[busca.first(-3).to_sym].options[:class_name].constantize
      else
        model = busca.last(3).eql?('_id') ? busca.titlecase.gsub(" ","").constantize : busca.singularize.camelize.constantize
      end
    else
      model = model_controller.reflections[busca.to_sym].options[:class_name]
      model = model.constantize if model.class == String
    end

    if model.column_names.include?('codigo')
      @object = model.order(:codigo).filtro_busca_select if validate_association(model_controller, busca) and defined? model.filtro_busca_select
    else
      @object = model.all.filtro_busca_select if validate_association(model_controller, busca) and defined? model.filtro_busca_select
    end

    render json: @object.to_json
  end

  def validate_association model, column
    (column.present? and model.reflections.include?(column.gsub('_id','').to_sym)) or (column.present? and model.reflections.include?(column.to_sym))
  end

end
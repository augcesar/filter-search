  def filter_search_button_help field
    return content_tag :button, "", class: "btn btn-success glyphicon glyphicon-plus form-search-add", type: "button" if field.first.blank?
    content_tag :button, "", class: "btn btn-danger glyphicon glyphicon-remove form-search-del", type: "button"
  end
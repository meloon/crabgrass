# Any time a view needs to specify some javascript, it should use a helper here instead.
# This way, if we need to switch javascript libraries, we can just edit the code here.

module JavascriptHelper

  # produces javascript to hide the given id or object
  def hide(id, extra=nil)
    id = dom_id(id,extra) if id.is_a?(ActiveRecord::Base)
    "$('%s').hide();" % id
  end

  # produces javascript to show the given id or object
  def show(id, extra=nil)
    id = dom_id(id,extra) if id.is_a?(ActiveRecord::Base)
    "$('%s').show();" % id
  end

  def reset_form(id)
    "$('#{id}').reset();"
    # "Form.getInputs($('#{id}'), 'submit').each(function(x){x.disabled=false}.bind(this));"
  end

  def replace_class_name(element_id, old_class, new_class)
    if element_id.is_a? String
      if element_id != 'this'
        element_id = "$('" + element_id + "')"
      end
    else
      element_id = "$('" + dom_id(element_id) + "')"
    end
    "replace_class_name(#{element_id}, '#{old_class}', '#{new_class}');"
  end

  def add_class_name(element_id, class_name)
    unless element_id.is_a? String
      element_id = dom_id(element_id)
    end
    "$('%s').addClassName('%s');" % [element_id, class_name]
  end

  def remove_class_name(element_id, class_name)
    unless element_id.is_a? String
      element_id = dom_id(element_id)
    end
    "$('%s').removeClassName('%s');" % [element_id, class_name]
  end

  def hide_spinner(id)
    "$('%s').hide();" % spinner_id(id)
  end
  def show_spinner(id)
    "$('%s').show();" % spinner_id(id)
  end

  def replace_html(element_id, html)
    element_id = dom_id(element_id) unless element_id.is_a?(String)
    %[$('%s').update(%s);] % [element_id, html.inspect]
  end

end


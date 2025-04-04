module ApplicationHelper
  include Pagy::Frontend

  def component(name, *, **)
    name = name.to_s.camelize.gsub('/', '::')
    component_class = "#{name.camelize}Component".constantize
    render(component_class.new(*, **))
  end

  def icon(name)
    component(:icon, name:)
  end
end

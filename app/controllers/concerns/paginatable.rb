module Paginatable
  extend ActiveSupport::Concern
  include Pagy::Method

  included do
    helper_method :pagy
  end
end

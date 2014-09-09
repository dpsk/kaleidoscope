module Kaleidoscope
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration
    # An array of reference colors
    attr_accessor :colors

    # Number of colors for output
    attr_accessor :number_of_colors
    attr_accessor :image_method
    attr_accessor :association_key
  end
end
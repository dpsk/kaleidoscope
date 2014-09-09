require 'kaleidoscope/errors/no_colors_configured'
require 'kaleidoscope/color_set'

module Kaleidoscope
  module InstanceMethods
    def colors_for
    end

    def generate_colors
      if has_colors_configured?

        destroy_colors

        Kaleidoscope.log("Generating colors for #{self.class.model_name}.")

        histogram = generate_histogram_for(magick_image)

        frequency_total = 0.0 # needs to be float

        array_of_pixels = []

        histogram.each do |h|
          # where h => [#<Magick::Pixel:0x007f948a736768>, 74558]
          # and h[0] is the Magick::Pixel
          # and h[1] is the histogram count
          # see, e.g. http://stackoverflow.com/questions/11282856/rmagicks-color-histogram-results-in-something-unlike-a-hash
          pixel = h[0]
          histogram_count = h[1]
          matched_pixel = compare_pixel_to_colors(pixel)
          array_of_pixels << { original_hex: hex_from_pixel(pixel), histogram_count: histogram_count, matched_hex: matched_pixel.to_hex, distance: distance_between(pixel: pixel, match: matched_pixel) }
          frequency_total += histogram_count
        end

        pixels_by_frequency = array_of_pixels.sort { |a, b| b[1] <=> a[1] }

        pixels_by_frequency.each do |pixel|
          frequency_percentage = histogram_count_to_percentage(pixel[:histogram_count], frequency_total)
          original_hex = sanitize_hex(pixel[:original_hex])
          matched_hex = sanitize_hex(pixel[:matched_hex])
          color_class.create(school_id: self.id, original_color: original_hex, reference_color: matched_hex, frequency: frequency_percentage, distance: pixel[:distance])
        end

      else
        Kaleidoscope.log("Kaleidoscope::NoColorsConfiguredError: No colors are configured in your Kaleidoscope initializer.")
        raise NoColorsConfiguredError
      end
    end

    def destroy_colors
      Kaleidoscope.log("Deleting colors for #{self.class.model_name}.")
      color_class.where(school_id: self.id).each(&:destroy)
    end

    private

    def kaleidoscope_config
      Kaleidoscope.configuration
    end

    def available_colors
      kaleidoscope_config.colors
    end

    def has_colors_configured?
      has_kaleidoscope_config? && has_available_colors?
    end

    def has_kaleidoscope_config?
      !kaleidoscope_config.nil?
    end

    def has_available_colors?
      !available_colors.nil? && !available_colors.empty?
    end

    # Possibly extract out these methods
    def read_image_into_imagemagick(image_url)
      Magick::Image.read(image_url).first
    end

    def generate_histogram_for(magick_image)
      magick_image.quantize(number_of_colors).color_histogram
    end

    def number_of_colors
      kaleidoscope_config.number_of_colors
    end

    def compare_pixel_to_colors(pixel)
      pixel_color = color_from(pixel)
      match_color = color_set.find_closest_to(pixel_color)
    end

    def color_from(pixel)
      Kaleidoscope::Color.from_pixel(pixel)
    end

    def color_set
      @color_set ||= Kaleidoscope::ColorSet.new(kaleidoscope_config.colors)
    end

    def histogram_count_to_percentage(histogram_count, frequency_total)
      percentage_of_histogram = histogram_count / frequency_total
      (percentage_of_histogram * 100.0).round(1)
    end

    def color_class
      Object.const_get("#{self.class.name}Color")
    end

    def magick_image
      @magick_image ||= read_image_into_imagemagick(magick_image_url)
    end

    def magick_image_url
    end

    def distance_between(pixel: pixel, match: match)
      pixel_color = color_from(pixel)
      pixel_color.distance_from(match)
    end

    def hex_from_pixel(pixel)
      pixel.to_color(Magick::AllCompliance,false,8)
    end

    def sanitize_hex(hex)
      hex.delete('#').downcase
    end
  end
end
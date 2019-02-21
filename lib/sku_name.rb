require 'sku_name/version'

module SkuName
  class Parse
    class Error < StandardError; end
    CONFIG_PATH = 'sku_name/config'.freeze

    attr_reader :skus
    attr_reader :config
    attr_reader :options

    # @param skus Array
    # @param config Hash
    def initialize(skus, config, options = {})
      @skus    = skus
      @config  = config
      @options = options
    end

    def process
      skus.map do |sku|
        next if options[:ignore_patterns].any? { |pattern| pattern =~ sku }

        {
          sku: sku,
          name: TranslateSku.new(sku, config, options).process
        }
      end.compact
    end
  end

  class TranslateSku
    class Error < StandardError; end
    attr_reader :sku
    attr_reader :config
    attr_reader :options
    attr_reader :delimeter

    def initialize(sku, config, options)
      @sku       = sku
      @config    = config
      @delimeter = options[:delimeter] || ' | '
    end

    def process
      parts = parse_parts

      # parts.sort_by! do |part|
      #   directive = config.keys[parts.index(part)]
      #   config[directive]['output_order']
      # end
      parts.join(delimeter)
    end

    private

    def parse_parts
      sku_c = sku.clone
      parts = []
      config.each do |directive, settings|
        break if sku_c.empty? && directive == 'extension'

        if sku_c.length < settings['length']
          break parts << 'ERROR: not valid length'
        end

        option_key = sku_c.slice!(0..(settings['length'] - 1))
        option_value = settings['options'][option_key]

        if option_value
          parts << option_value
        elsif directive == 'extension'
          # nothing
        else
          parts << "ERROR: no option value for: #{option_key}"
        end
      end
      parts
    end
  end
end

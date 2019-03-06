require 'sku_name/version'

module SkuName; end

class SkuName::Parse
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
    skus.each_with_object({}) do |sku, memo|
      next if options[:ignore_patterns].any? { |pattern| pattern =~ sku }

      memo[sku] = SkuName::SkuExpand.new(sku, config, options).process
    end
  end
end

class SkuName::SkuExpand
  class Error < StandardError; end
  attr_reader :sku
  attr_reader :config
  attr_reader :options

  def initialize(sku, config, options)
    @sku     = sku
    @config  = config
    @options = options
  end

  def process
    expand
  end

  def expand
    sku_c = sku.clone
    config_handle = config.clone
    positions.each_with_object({}) do |(_position, settings), memo|
      # Stub out optional positions with nil if empty.
      # NOTE: Optional values can only be at the end.
      if sku_c.empty? && settings['optional']
        memo[settings['name']] = {
          abbreviation: nil,
          expansion:    nil
        }
      end

      break memo if sku_c.empty?

      # ensure SKU is proper length
      if sku_c.length < settings['length']
        error_details = {
          settings['name'] => {
            abbreviation: 'ERROR: invalid SKU length',
            expansion:    'ERROR: invalid SKU length'
          }
        }
        puts error_details
        memo.merge!(error_details)
        next
      end

      # extract next portion from sku
      sku_abbreviation = sku_c.slice!(0..(settings['length'] - 1))
      config_scope = config_handle[settings['options_path']]

      # ensure option values are defined for this sku_abbreviation
      unless config_scope
        error_details = {
          settings['name'] => {
            abbreviation: sku_abbreviation,
            expansion:
              "ERROR: option values missing for '#{settings['options_path']}'"
          }
        }
        puts error_details
        memo.merge!(error_details)
        next
      end

      # ensure this sku_abbreviation exists in config
      begin
        expansion_scope = config_scope[sku_abbreviation]
      rescue NoMethodError => e
        raise e unless e.message == "undefined method `[]' for nil:NilClass"

        raise Error, "ERROR: no #{sku_abbreviation} within #{config_scope}"
      end

      # ensure an option value exists for this option
      unless expansion_scope
        error_details = {
          settings['name'] => {
            abbreviation: sku_abbreviation,
            expansion:
              "ERROR: '#{settings['options_path']}' does not have a value " \
              "option for '#{sku_abbreviation}'"
          }
        }
        puts error_details
        memo.merge!(error_details)
        next
      end

      # move handle if within parent scope
      config_handle = expansion_scope if settings['parent']

      # ensure sku_expansion is defined
      sku_expansion = begin
        if settings['options_name_path']
          begin
            expansion_scope[settings['options_name_path']]
          rescue NoMethodError => e
            raise e unless e.message.include? == "undefined method `[]'"

            raise(
              Error,
              'ERROR: config file missing ' \
              "'#{settings['options_name_path']}' within '#{sku_abbreviation}'"
            )
          end
        else
          expansion_scope
        end
      end

      # expanding this sku_abbreviation was successful, store results
      memo[settings['name']] = {
        abbreviation: sku_abbreviation,
        expansion:    sku_expansion
      }
    end
  end

  def positions
    config['sku_positions']
  end
end

require 'spec_helper'
require 'csv'
require 'psych'

RSpec.describe SkuName::Parse do
  it 'has a version number' do
    expect(SkuName::VERSION).not_to be nil
  end

  let(:sku_file_path) { 'spec/fixtures/skus.csv' }
  let(:config_file_path) { 'spec/fixtures/config.yml' }
  let(:output_names_path) { 'tmp/skus_shipping_easy.csv' }
  let(:output_details_path) { 'tmp/skus_descriptions.csv' }

  it 'generates names from skus' do
    skus = CSV.read(sku_file_path).flatten
    config = Psych.load_file(config_file_path)

    sku_name = described_class.new(
      skus, config, ignore_patterns: [/^PF_/, /^S1-/, /^S2-/, /^(?![A-Z]).*/]
    )
    results = sku_name.process

    expect(results).to be_a Hash
    expect(results.first).to be_an Array

    Dir.mkdir 'tmp' unless Dir.exist? 'tmp'

    results = results.sort_by { |sku, _| sku }.to_h

    # Details
    rows = results.map do |sku, meta|
      values = meta.values.map { |value| value[:expansion] }
      [sku, values.compact.join(' | '), values].flatten
    end

    CSV.open(output_details_path, 'wb') do |csv|
      # headers
      csv << ['sku', 'name', results.first[1].keys].flatten
      # row values
      rows.each do |row|
        csv << row
      end
    end

    # Names only
    rows = results.map do |sku, meta|
      expansions = meta.map do |_, abbr_exp|
        abbr_exp[:expansion]
      end
      [sku, expansions.compact.join(' | '), 'On']
    end

    CSV.open(output_names_path, 'wb') do |csv|
      # headers
      csv << ['SKU', 'name', 'Override Store Name']
      # row values
      rows.each do |row|
        csv << row
      end
    end
  end
end

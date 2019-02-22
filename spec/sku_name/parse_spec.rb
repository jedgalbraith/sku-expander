require 'spec_helper'
require 'csv'
require 'psych'

RSpec.describe SkuName::Parse do
  it 'has a version number' do
    expect(SkuName::VERSION).not_to be nil
  end

  let(:sku_file_path) { 'spec/fixtures/skus.csv' }
  let(:config_file_path) { 'spec/fixtures/config.yml' }
  let(:output_names_path) { 'tmp/skus_names.csv' }
  let(:output_details_path) { 'tmp/skus_details.csv' }

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

    rows = results.map do |sku, meta|
      values = meta.values.map { |value| value[:expansion] }
      [sku, values].flatten
    end

    CSV.open(output_details_path, 'wb') do |csv|
      csv << ['sku', results.first[1].keys].flatten
      rows.each do |row|
        csv << row
      end
    end

    rows = results.map do |sku, meta|
      expansions = meta.map do |_, abbr_exp|
        abbr_exp[:expansion]
      end
      [sku, expansions.compact.join(' | ')]
    end

    CSV.open(output_names_path, 'wb') do |csv|
      csv << ['SKU', 'name']
      rows.each do |row|
        csv << row
      end
    end
  end
end

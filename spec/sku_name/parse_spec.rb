require 'spec_helper'
require 'csv'
require 'psych'

RSpec.describe SkuName::Parse do
  it 'has a version number' do
    expect(SkuName::VERSION).not_to be nil
  end

  let(:sku_file_path) { 'spec/fixtures/skus.csv' }
  let(:config_file_path) { 'spec/fixtures/config.yml' }
  let(:output_path) { 'tmp/skus_names.csv' }

  it 'generates names from skus' do
    skus = CSV.read(sku_file_path).flatten
    config = Psych.load_file(config_file_path)

    sku_name = described_class.new(
      skus, config, ignore_patterns: [/^PF_/, /^S1-/, /^S2-/, /^(?![A-Z]).*/]
    )
    results = sku_name.process

    expect(results).to be_an Array
    expect(results.first).to be_a Hash

    Dir.mkdir 'tmp' unless Dir.exist? 'tmp'

    results.sort_by! do |result|
      result[:name]
    end
    rows = results.map do |result|
      [result[:sku], result[:name]]
    end

    CSV.open(output_path, 'wb') do |csv|
      csv << results.first.keys
      rows.each do |row|
        csv << row
      end
    end
  end
end

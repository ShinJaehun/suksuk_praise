require 'rails_helper'
require 'yaml'

RSpec.describe 'locale structure' do
  locale_files = Rails.root.glob('config/locales/*.yml').sort
  korean_locale_files = Rails.root.glob('config/locales/ko*.yml').sort

  def leaf_paths(value, prefix = [], paths = [])
    if value.is_a?(Hash)
      value.each { |key, child| leaf_paths(child, prefix + [key.to_s], paths) }
    else
      paths << prefix.join('.')
    end

    paths
  end

  it 'parses every locale YAML file' do
    locale_files.each do |file|
      expect { YAML.safe_load_file(file, aliases: true) }.not_to raise_error
    end
  end

  it 'keeps ko as the only root key in every Korean locale file' do
    korean_locale_files.each do |file|
      expect(YAML.safe_load_file(file, aliases: true).keys).to eq(['ko'])
    end
  end

  it 'does not duplicate Korean translation leaf paths across files' do
    owners = Hash.new { |hash, key| hash[key] = [] }

    korean_locale_files.each do |file|
      translations = YAML.safe_load_file(file, aliases: true).fetch('ko')
      leaf_paths(translations).each { |path| owners[path] << file.basename.to_s }
    end

    duplicates = owners.select { |_path, files| files.many? }
    expect(duplicates).to be_empty,
      "duplicate Korean translation keys: #{duplicates.inspect}"
  end

  it 'loads representative Korean translations' do
    keys = %w[
      activerecord.errors.models.classroom.attributes.base.students_or_history_present
      navigation.dashboard
      classrooms.create.success
      students.bulk_create.success
      coupons.draw.success
      compliments.create.success
      schools.index.title
    ]

    expect(keys).to all(satisfy { |key| I18n.exists?(key, :ko) })
  end
end

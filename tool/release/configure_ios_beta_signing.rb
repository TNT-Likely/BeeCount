# Only a private frozen source copy is passed by ios_beta_release.py.
require 'json'
require 'xcodeproj'
project = Xcodeproj::Project.open(ARGV.fetch(0))
config = JSON.parse(File.read(ARGV.fetch(1)))
expected = {'Runner' => ['com.tntlikely.beecount', config.fetch('mainProfile')],
            'BeeCountWidgetExtension' => ['com.tntlikely.beecount.BeeCountWidgetExtension', config.fetch('widgetProfile')]}
raise 'Expected App and Widget targets missing' unless (expected.keys - project.targets.map(&:name)).empty?
project.targets.each do |target|
  next unless expected.key?(target.name)
  bundle, profile = expected.fetch(target.name)
  target.build_configurations.each do |build|
    next unless %w[Release Profile].include?(build.name)
    settings = build.build_settings
    settings.keys.grep(/\ACODE_SIGN_IDENTITY/).each { |key| settings.delete(key) }
    settings['CODE_SIGN_STYLE'] = 'Manual'
    settings['CODE_SIGN_IDENTITY'] = config.fetch('certificate')
    settings['DEVELOPMENT_TEAM'] = config.fetch('team')
    settings['PROVISIONING_PROFILE_SPECIFIER'] = profile
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle
    settings['CURRENT_PROJECT_VERSION'] = config.fetch('buildNumber')
    settings['MARKETING_VERSION'] = config.fetch('appVersion')
  end
end
project.save

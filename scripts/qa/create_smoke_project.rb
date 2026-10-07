require 'xcodeproj'
base=ARGV.fetch(0)
project=Xcodeproj::Project.new(File.join(base, 'QASmoke.xcodeproj'))
target=project.new_target(:ui_test_bundle, 'QASmoke', :ios, '16.0')
file=project.main_group.new_file('QASmoke.swift')
target.source_build_phase.add_file_reference(file)
target.build_configurations.each do |config|
 config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']='com.tntlikely.beecount.qa.smoke'
 config.build_settings['GENERATE_INFOPLIST_FILE']='YES'
 config.build_settings['SWIFT_VERSION']='5.0'
 config.build_settings['CODE_SIGNING_ALLOWED']='NO'
 config.build_settings['TARGETED_DEVICE_FAMILY']='1'
end
project.save
scheme=Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.save_as(project.path, 'QASmoke', true)

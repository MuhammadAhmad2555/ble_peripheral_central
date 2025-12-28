#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint ble_peripheral_central.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ble_peripheral_central'
  s.version          = '1.0.0'
  s.summary          = 'A Flutter plugin for dual-mode BLE Peripheral and Central operations'
  s.description      = <<-DESC
A Flutter plugin that enables a mobile device to simultaneously act as both a Bluetooth Low Energy (BLE) Peripheral (server/advertiser) and a BLE Central (client/scanner), enabling peer-to-peer mesh networking scenarios.
                       DESC
  s.homepage         = 'https://github.com/MuhammadAhmad2555/ble_peripheral_central'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'ble_peripheral_central_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end

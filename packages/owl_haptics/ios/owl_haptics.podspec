#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint owl_haptics.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'owl_haptics'
  s.version          = '0.1.0'
  s.summary          = 'Short, semantic, cancelable haptics for Flutter.'
  s.description      = <<-DESC
Short foreground UI haptics with semantic effects, bounded pulse sequences,
cancelable handles, lifecycle cleanup, and capability-aware native fallbacks.
                       DESC
  s.homepage         = 'https://github.com/Owl-YH/app_plugins/tree/main/packages/owl_haptics'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Heng Yang' => 'https://mycards.owlllwo.com' }
  s.source           = { :path => '.' }
  s.source_files = 'owl_haptics/Sources/owl_haptics/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'owl_haptics_privacy' => ['owl_haptics/Sources/owl_haptics/PrivacyInfo.xcprivacy']}
end

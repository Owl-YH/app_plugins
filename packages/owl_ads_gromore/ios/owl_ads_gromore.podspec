#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint owl_ads_gromore.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'owl_ads_gromore'
  s.version          = '0.1.0'
  s.summary          = 'GroMore mediation provider for owl_ads.'
  s.description      = <<-DESC
Typed Flutter integration for GroMore reward and full-screen insert ads.
                       DESC
  s.homepage         = 'https://github.com/Owl-YH/app_plugins/tree/main/packages/owl_ads_gromore'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Heng Yang'
  s.source           = { :path => '.' }
  s.source_files = 'owl_ads_gromore/Sources/owl_ads_gromore/**/*.swift'
  s.static_framework = true
  s.dependency 'Flutter'
  s.dependency 'Ads-CN/BUAdSDK', '7.7.0.6'
  s.dependency 'Ads-CN/CSJMediation-Only', '7.7.0.6'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'owl_ads_gromore_privacy' => ['owl_ads_gromore/Sources/owl_ads_gromore/PrivacyInfo.xcprivacy']}
end

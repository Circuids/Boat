#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint boat.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'boat'
  s.version          = '1.0.0'
  s.summary          = 'Production-grade realtime voice and audio engine for Flutter.'
  s.description      = <<-DESC
Production-grade realtime voice and audio engine with OS-level AEC, AGC, and noise suppression.
                       DESC
  s.homepage         = 'https://github.com/circuids/boat'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'circuids' => 'circuids@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Privacy manifest declaring microphone usage and required-reason APIs.
  s.resource_bundles = {'boat_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end

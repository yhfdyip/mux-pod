Pod::Spec.new do |s|
  s.name         = 'libmoshios'
  s.version      = '1.3.2'
  s.summary      = 'libmoshios prebuilt framework'
  s.homepage     = 'https://github.com/blinksh/build-mosh'
  s.license      = { :type => 'GPLv3' }
  s.author       = 'Blink Shell'
  s.platform     = :ios, '13.0'
  s.source       = { :path => '.' }
  s.vendored_frameworks = 'libmoshios.framework'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end

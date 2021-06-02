Pod::Spec.new do |s|
  s.name = 'Smooth'
  s.version = '0.1.1'
  s.summary = 'Interpolate number arrays'
  s.description = 'Heavily based on [Smooth.js](https://github.com/osuushi/Smooth.js/). Smoothing and interpolation number arrays.'
  s.homepage = 'https://github.com/ryohey/Smooth.swift'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'ryohey' => 'info@codingcafe.jp' }
  s.source = { :git => 'https://github.com/ryohey/Smooth.swift.git', :tag => s.version.to_s }
  s.platforms = { :ios => '9.0', :watchos => '2.0' }
  s.swift_version = '4.2'
  s.source_files = 'Sources/Core/**/*'
  s.framework = 'Foundation'
end

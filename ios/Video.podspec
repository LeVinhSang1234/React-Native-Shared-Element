Pod::Spec.new do |s|
  s.name         = 'ShareVideo'
  s.version      = '1.0.0'
  s.summary      = 'A custom video view for iOS, using KTVHTTPCache.'
  s.description  = 'Custom iOS video view with KTVHTTPCache and shared element support.'
  s.homepage     = 'https://github.com/yourusername/Video'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Your Name' => 'your@email.com' }
  s.source       = { :git => 'https://github.com/yourusername/Video.git', :tag => s.version }
  s.platform     = :ios, '13.0'
  s.source_files = 'Video/**/*.{h,m,swift}'
  s.requires_arc = true
  s.dependency   'KTVHTTPCache'
end
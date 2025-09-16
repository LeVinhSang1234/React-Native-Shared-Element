require 'json'

fabric_enabled = ENV['RCT_NEW_ARCH_ENABLED'] == '1'
package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name         = 'rn-shared-element'
  s.version      = '1.0.0'
  s.summary      = 'A custom video view for iOS, using KTVHTTPCache.'
  s.description  = 'Custom iOS video view with KTVHTTPCache and shared element support.'
  s.homepage     = 'https://github.com/LeVinhSang1234/React-Native-Shared-Element/tree/share-video'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Sang Le' => 'lsang2884@email.com' }

  s.platforms    = { :ios => "13.0" }
  s.source       = { :git => "https://github.com/LeVinhSang1234/React-Native-Shared-Element", :tag => "v#{s.version}" }
  s.requires_arc = true
  s.swift_version = "5.0"

  s.frameworks   = ["AVFoundation", "CoreMedia"]

  # ObjC / C++ sources (không chứa Fabric)
  s.source_files  = "ios/**/*.{h,m,mm,cpp}"
  s.exclude_files = "ios/Fabric"

  # Base deps
  s.dependency "React-Core"
  s.dependency "KTVHTTPCache"

  if fabric_enabled
    install_modules_dependencies(s)

    # Common C++ (codegen interop)
    s.subspec "common" do |ss|
      ss.source_files        = "common/cpp/**/*.{cpp,h}"
      ss.header_dir          = "react/renderer/components/ShareElement"
      ss.pod_target_xcconfig = { "HEADER_SEARCH_PATHS" => "\"$(PODS_TARGET_SRCROOT)/common/cpp\"" }
    end

    # Fabric-specific bridging
    s.subspec "fabric" do |ss|
      ss.dependency "rn-shared-element/common"
      ss.source_files        = "ios/Fabric/**/*.{h,m,mm,cpp}"
      ss.pod_target_xcconfig = { "HEADER_SEARCH_PATHS" => "\"$(PODS_TARGET_SRCROOT)/common/cpp\"" }
    end
  end

  # Patch KTVHTTPCache bug automatically
  s.prepare_command = <<-CMD
    files=$(find Pods -name KTVHCRange.h 2>/dev/null || true)
    for file in $files; do
      sed -i '' -e 's/LONG_LONG_MAX/LLONG_MAX/g' "$file"
    done
  CMD
end
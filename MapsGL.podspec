Pod::Spec.new do |spec|
  repository_path = 'vaisala-xweather/mapsgl-apple-sdk'
  
  spec.name         = "MapsGL"
  spec.version      = "1.2.2"
  spec.summary      = "MapsGL is an easy-to-use, highly customizable Swift SDK for visualizing both weather and custom data, powered by Metal."
  spec.description  = <<-DESC
MapsGL Apple SDK is a powerful mapping library designed for iOS developers. It enables the integration of MapsGL's rich mapping features into iOS applications, providing a seamless and interactive user experience.
  DESC
  spec.readme = "https://raw.githubusercontent.com/#{repository_path}/v#{spec.version.to_s}/README.md"
  spec.homepage     = "https://github.com/#{repository_path}"
  spec.screenshots  = "https://raw.githubusercontent.com/#{repository_path}/v#{spec.version.to_s}/images/MapsGL-iPad-PM10-layer.png"
  spec.license      = { :type => 'MIT', :file => 'LICENSE' }
  spec.author             = { "Vaisala Xweather" => "https://www.xweather.com/" }
  spec.social_media_url   = "https://twitter.com/vaisalaxweather"
  spec.platforms    = { :ios => '16.0' }
  spec.swift_versions = [ '5' ]
  spec.source       = {
    http: "https://github.com/#{repository_path}/releases/download/v#{spec.version.to_s}/MapsGL.zip",
    sha256: "d2c60d88294b7cc181bddf489e6ab752c97aa055b8e745bc2255afbf65aaf5c1",
    flatten: true
  }
  spec.default_subspecs = 'Core', 'Renderer', 'Maps', 'Mapbox'
  
  spec.subspec 'Core' do |subspec|
    subspec.vendored_frameworks = 'MapsGLCore.xcframework'
    subspec.frameworks = 'Foundation', 'CoreLocation', 'OSLog', 'UIKit'
  end
  
  spec.subspec 'Renderer' do |subspec|
    subspec.vendored_frameworks = 'MapsGLRenderer.xcframework'
    subspec.frameworks = 'Foundation', 'CoreGraphics', 'Metal', 'MetalKit', 'OSLog', 'SwiftUI'
    subspec.dependency 'MapsGL/Core'
  end
  
  spec.subspec 'Maps' do |subspec|
    subspec.vendored_frameworks = 'MapsGLMaps.xcframework'
    subspec.frameworks = 'Foundation', 'Combine', 'CoreGraphics', 'CoreLocation', 'ImageIO', 'Metal', 'OSLog', 'UIKit', 'UniformTypeIdentifiers'
    subspec.dependency 'MapsGL/Core'
    subspec.dependency 'MapsGL/Renderer'
  end
  
  spec.subspec 'Mapbox' do |subspec|
    subspec.source_files = 'MapsGLMapbox/**/*'
    subspec.frameworks = 'Foundation', 'Combine', 'CoreLocation', 'Metal', 'OSLog'
    subspec.dependency 'MapsGL/Maps'
    subspec.dependency 'MapboxMaps', '~> 11.0'
  end

end

Pod::Spec.new do |spec|
  spec.name         = "MapsGL"
  spec.version      = "1.0.2"
  spec.summary      = "MapsGL is an easy-to-use, highly customizable Swift SDK for visualizing both weather and custom data, powered by Metal."
  spec.description  = <<-DESC
MapsGL Apple SDK is a powerful mapping library designed for iOS developers. It enables the integration of MapsGL's rich mapping features into iOS applications, providing a seamless and interactive user experience.
  DESC
  spec.readme = "https://raw.githubusercontent.com/vaisala-xweather/mapsgl-apple-sdk/v#{spec.version.to_s}/README.md"
  spec.homepage     = "https://github.com/vaisala-xweather/mapsgl-apple-sdk"
  spec.screenshots  = "https://raw.githubusercontent.com/vaisala-xweather/mapsgl-apple-sdk/v#{spec.version.to_s}/images/MapsGL-iPad-PM10-layer.png"
  #spec.license      = { :type => 'BSD', :file => 'LICENSE.md' }
  spec.author             = { "Vaisala Xweather" => "https://www.xweather.com/" }
  spec.social_media_url   = "https://twitter.com/vaisalaxweather"
  spec.platforms    = { :ios => '16.0' }
  spec.source       = {
    http: "https://github.com/vaisala-xweather/mapsgl-apple-sdk/releases/download/v#{spec.version.to_s}/MapsGL.zip",
    sha256: "3481cd48a19857cabe71a6c4d69e07434d287811da7d9de36bda46e231ad9c5c",
    flatten: true
  }
  spec.default_subspecs = 'Core', 'Renderer', 'Maps', 'Mapbox'
  
  spec.subspec 'Core' do |subspec|
    subspec.vendored_frameworks = 'MapsGLCore.xcframework'
    subspec.frameworks = 'Foundation', 'CoreLocation', 'Darwin', 'Dispatch', 'OSLog', 'Swift', 'UIKit'
  end
  
  spec.subspec 'Renderer' do |subspec|
    subspec.vendored_frameworks = 'MapsGLRenderer.xcframework'
    subspec.frameworks = 'Foundation', 'CoreGraphics', 'Metal', 'MetalKit', 'OSLog', 'Spatial', 'Swift', 'SwiftUI', 'simd'
    subspec.dependency 'MapsGL/Core'
  end
  
  spec.subspec 'Maps' do |subspec|
    subspec.vendored_frameworks = 'MapsGLMaps.xcframework'
    subspec.frameworks = 'Foundation', 'Combine', 'CoreGraphics', 'CoreLocation', 'ImageIO', 'Metal', 'OSLog', 'Spatial', 'Swift', 'UIKit', 'UniformTypeIdentifiers', 'simd'
    subspec.dependency 'MapsGL/Core'
    subspec.dependency 'MapsGL/Renderer'
  end
  
  spec.subspec 'Mapbox' do |subspec|
    subspec.vendored_frameworks = 'MapsGLMapbox.xcframework'
    subspec.frameworks = 'Foundation', 'Combine', 'CoreLocation', 'Metal', 'OSLog', 'Spatial', 'Swift'
    subspec.dependency 'MapsGL/Maps'
    subspec.dependency 'MapboxMaps', '~> 11.0'
  end

end

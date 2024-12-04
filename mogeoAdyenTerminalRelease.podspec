
Pod::Spec.new do |s|
  s.name         = "mogeoAdyenTerminalRelease"
  s.module_name  = "mogeoAdyenTerminal"
  s.version      = "0.1.0"
  s.summary      = 'Provide the encapsulation of the Adyen POS payment component to the RN layer'
  s.homepage     = "https://www.moego.pet/"
  s.license      = "MIT"
  s.authors      = "moego"

  s.platform     = :ios, "13.4"
  s.source       = { :git => "https://github.com/Adyen/adyen-react-native.git", :tag => "#{s.version}" }
  s.source_files = "ios/src/**/*.{h,m,swift}"


  s.dependency "React-Core"
  s.resource_bundles = { 'mogeoAdyenTerminal' => [ 'ios/PrivacyInfo.xcprivacy' ] }

  
  s.vendored_frameworks = [
    "ios/lib/Release/AdyenPOS.xcframework",
  ]

end

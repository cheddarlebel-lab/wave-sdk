require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "wave-unlock-react-native"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = "https://github.com/cheddarlebel-lab/wave-sdk"
  s.license      = "MIT"
  s.author       = "Passport Technologies"
  s.platforms    = { :ios => "15.0" }
  s.source       = { :git => "https://github.com/cheddarlebel-lab/wave-sdk.git", :tag => "#{s.version}" }
  s.source_files = "ios/**/*.{h,m,swift}"
  s.swift_version = "5.9"

  s.dependency "React-Core"
  # The Swift core. Published as a pod / resolved via SPM in the host app.
  s.dependency "WaveUnlock"
end

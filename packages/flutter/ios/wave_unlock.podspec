Pod::Spec.new do |s|
  s.name             = "wave_unlock"
  s.version          = "0.1.0"
  s.summary          = "Wave Passport BLE door unlock for Flutter."
  s.homepage         = "https://github.com/cheddarlebel-lab/wave-sdk"
  s.license          = { :type => "MIT" }
  s.author           = "Passport Technologies"
  s.source           = { :path => "." }
  s.source_files     = "Classes/**/*"
  s.dependency "Flutter"
  s.dependency "WaveUnlock" # the Swift core
  s.platform = :ios, "15.0"
  s.swift_version = "5.9"
end

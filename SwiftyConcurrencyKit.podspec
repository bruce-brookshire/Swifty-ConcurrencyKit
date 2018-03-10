Pod::Spec.new do |s|
  s.name             = 'SwiftyConcurrencyKit'
  s.version          = '0.1'
  s.summary          = 'Functional and concurrent classes to provide easy data processing in the style of Java 8'
 
  s.description      = <<-DESC
API's for efficient and versatile task oriented concurrent processing to minimize setup required for long running background tasks.
                       DESC
 
  s.homepage         = 'https://github.com/flyrboy96/Swifty-ConcurrencyKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Bruce Brookshire' => 'bruce.t.brookshire@gmail.com' }
  s.source           = { :git => 'https://github.com/flyrboy96/Swifty-ConcurrencyKit.git', :tag => s.version.to_s }
 
  s.ios.deployment_target = '9.3'
  s.source_files = 'Swifty-ConcurrencyKit/Swifty-ConcurrencyKit/*.swift'
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.0' } 
end

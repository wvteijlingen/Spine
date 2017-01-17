Pod::Spec.new do |s|
  s.name = 'Spine'
  s.version = '0.3'
  s.license = 'MIT'
  s.summary = 'A Swift library for interaction with a jsonapi.org API'
  s.homepage = 'https://github.com/wvteijlingen/Spine'
  s.authors = { 'Ward van Teijlingen' => 'w.van.teijlingen@gmail.com' }
  s.source = { :git => 'https://github.com/wvteijlingen/Spine.git', :tag => s.version }

  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '9.0'
  s.osx.deployment_target = '10.10'

  s.source_files = 'Spine/*.swift'

  s.requires_arc = true

  s.dependency 'SwiftyJSON', '~> 3.1.4'
  s.dependency 'BrightFutures', '~> 5.0'
end

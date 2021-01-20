Pod::Spec.new do |s|
  s.name             = 'EasyPagingView'
  s.version          = '1.1.0'
  s.summary          = '功能强大，容易使用的多列表控件'
 
  s.description      = <<-DESC
    功能强大，容易使用的多列表控件，方便集成。
                       DESC
 
  s.swift_version    = '5.0'
  s.homepage         = 'https://github.com/quanhuapeng/EasyPagingView'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'pengquanhua' => 'im.pengqh@gmail.com' }
  s.source           = { :git => 'https://github.com/quanhuapeng/EasyPagingView.git', :tag => s.version }
 
  s.ios.deployment_target = '11.0'
  s.source_files = 'EasyPagingView/*.{swift}'
  s.static_framework = true
end

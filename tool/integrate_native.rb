require 'xcodeproj'
project=Xcodeproj::Project.open('ios/Runner.xcodeproj')
app=project.targets.find{|target|target.name=='Runner'}
raise 'Runner target missing' unless app
local=project.root_object.package_references.find{|reference|reference.respond_to?(:relative_path) && reference.relative_path=='SuperModules'}
unless local
  local=project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  local.relative_path='SuperModules'
  project.root_object.package_references << local
end
%w[CareHealthKit CryptoResearchKit].each do |name|
  next if app.package_product_dependencies.any?{|dependency|dependency.product_name==name}
  dependency=project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.product_name=name
  app.package_product_dependencies << dependency
  build=project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build.product_ref=dependency
  app.frameworks_build_phase.files << build
end
runner=project.main_group.find_subpath('Runner',false)
unless runner.files.any?{|file|file.path=='NativeSuitePresenter.swift'}
  app.source_build_phase.add_file_reference(runner.new_file('NativeSuitePresenter.swift'))
end
unless project.targets.any?{|target|target.name=='HealthWidgets'}
  target=project.new_target(:app_extension,'HealthWidgets',:ios,'16.2')
  group=project.main_group.new_group('HealthWidgets','HealthWidgets')
  Dir.glob('ios/HealthWidgets/*.swift').sort.each{|path|target.source_build_phase.add_file_reference(group.new_file(File.basename(path)))}
  shared=group.new_group('Shared','Shared')
  Dir.glob('ios/HealthWidgets/Shared/*.swift').sort.each{|path|target.source_build_phase.add_file_reference(shared.new_file(File.basename(path)))}
  target.build_configurations.each do |config|
    config.build_settings.merge!({'INFOPLIST_FILE'=>'HealthWidgets/Info.plist','GENERATE_INFOPLIST_FILE'=>'NO','SWIFT_VERSION'=>'5.0','APPLICATION_EXTENSION_API_ONLY'=>'YES','SKIP_INSTALL'=>'YES','TARGETED_DEVICE_FAMILY'=>'1,2','LD_RUNPATH_SEARCH_PATHS'=>'$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'})
  end
  app.add_dependency(target)
  phase=app.copy_files_build_phases.find{|item|item.name=='Embed App Extensions'} || app.new_copy_files_build_phase('Embed App Extensions')
  phase.dst_subfolder_spec=Xcodeproj::Constants::COPY_FILES_BUILD_PHASE_DESTINATIONS.fetch(:plug_ins)
  phase.add_file_reference(target.product_reference).settings={'ATTRIBUTES'=>['RemoveHeadersOnCopy']}
  app.build_phases.delete(phase)
  index=app.build_phases.index{|item|item.respond_to?(:name)&&item.name=='Thin Binary'}
  app.build_phases.insert(index || 0,phase)
end
unless app.resources_build_phase.files_references.any?{|file|file.path=='research-sleep.onnx'}
  group=project.main_group.new_group('HealthResources','HealthResources')
  app.resources_build_phase.add_file_reference(group.new_file('research-sleep.onnx'))
end
project.targets.each do |target|
  next unless ['Runner','DepartureWidget','HealthWidgets'].include?(target.name)
  id=target.name=='Runner' ? 'app.caresuite.super' : target.name=='DepartureWidget' ? 'app.caresuite.super.barklive' : 'app.caresuite.super.healthlive'
  target.build_configurations.each do |config|
    config.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER'=>id,'MARKETING_VERSION'=>'0.1.1','CURRENT_PROJECT_VERSION'=>'2','CODE_SIGNING_ALLOWED'=>'NO','CODE_SIGNING_REQUIRED'=>'NO'})
    if target.name!='Runner'
      config.build_settings['PRODUCT_NAME']=target.name
      config.build_settings['PRODUCT_MODULE_NAME']=target.name
      config.build_settings['EXECUTABLE_NAME']='$(PRODUCT_NAME)'
    end
    if target.name=='Runner'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']='16.0'
      config.build_settings['CODE_SIGN_ENTITLEMENTS']='Runner/CareSuite.entitlements'
    end
  end
end
unless project.targets.any?{|target|target.name=='SuperSuiteUITests'}
  tests=project.new_target(:ui_test_bundle,'SuperSuiteUITests',:ios,'16.0')
  group=project.main_group.new_group('SuperSuiteUITests','SuperSuiteUITests')
  tests.source_build_phase.add_file_reference(group.new_file('NativeModulesTests.swift'))
  tests.add_dependency(app)
  tests.build_configurations.each do |config|
    config.build_settings.merge!({'TEST_TARGET_NAME'=>'Runner','PRODUCT_BUNDLE_IDENTIFIER'=>'app.caresuite.super.uitests','SWIFT_VERSION'=>'5.0','GENERATE_INFOPLIST_FILE'=>'YES','CODE_SIGNING_ALLOWED'=>'NO'})
  end
  path='ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme'
  scheme=Xcodeproj::XCScheme.new(path)
  scheme.add_test_target(tests)
  scheme.save_as('ios/Runner.xcodeproj','Runner',true)
end
project.save
puts 'Single Runner + health/crypto Swift packages + two widget extensions configured.'

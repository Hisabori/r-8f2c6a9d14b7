platform :ios, '16.0'
project 'CareSuiteNative.xcodeproj'
use_frameworks! :linkage => :static
target 'CareSuiteNative' do
  pod 'TensorFlowLiteSwift', '2.12.0'
  pod 'onnxruntime-objc', '1.20.0'
  target 'NativeTests' do
    inherit! :search_paths
  end
end

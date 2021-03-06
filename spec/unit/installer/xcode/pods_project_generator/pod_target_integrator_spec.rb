require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        class PodTargetIntegrator
          describe 'In general' do
            before do
              @project = Pod::Project.new(config.sandbox.project_path)
              @project.save
              @target_definition = fixture_target_definition
              @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
              @coconut_pod_target = PodTarget.new([@coconut_spec, *@coconut_spec.recursive_subspecs], [@target_definition], config.sandbox)
              @native_target = stub('NativeTarget', :shell_script_build_phases => [], :build_phases => [], :project => @project)
              @test_native_target = stub('TestNativeTarget', :symbol_type => :unit_test_bundle, :build_phases => [], :shell_script_build_phases => [], :project => @project)
              @coconut_pod_target.stubs(:native_target).returns(@native_target)
              @coconut_pod_target.stubs(:test_native_targets).returns([@test_native_target])
            end

            describe '#integrate!' do
              it 'integrates test native targets with frameworks and resources script phases' do
                PodTargetIntegrator.new(@coconut_pod_target).integrate!
                @test_native_target.build_phases.count.should == 2
                @test_native_target.build_phases.map(&:display_name).should == [
                  '[CP] Embed Pods Frameworks',
                  '[CP] Copy Pods Resources',
                ]
                @test_native_target.build_phases[0].shell_script.should == "\"${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-frameworks.sh\"\n"
                @test_native_target.build_phases[1].shell_script.should == "\"${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-resources.sh\"\n"
              end

              it 'clears input and output paths from script phase if it exceeds limit' do
                # The paths represented here will be 501 for input paths and 501 for output paths which will exceed the limit.
                resource_paths = (0..500).map do |i|
                  "${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugLibPng#{i}.png"
                end
                @coconut_pod_target.stubs(:resource_paths).returns(resource_paths)
                PodTargetIntegrator.new(@coconut_pod_target).integrate!
                @test_native_target.build_phases.map(&:display_name).should == [
                  '[CP] Embed Pods Frameworks',
                  '[CP] Copy Pods Resources',
                ]
                @test_native_target.build_phases[1].input_paths.should == []
                @test_native_target.build_phases[1].output_paths.should == []
              end

              it 'integrates test native targets with frameworks and resources script phase input and output paths' do
                framework_paths = { :name => 'Vendored.framework', :input_path => '${PODS_ROOT}/Vendored/Vendored.framework', :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/Vendored.framework' }
                resource_paths = ['${PODS_CONFIGURATION_BUILD_DIR}/TestResourceBundle.bundle']
                @coconut_pod_target.stubs(:framework_paths).returns(framework_paths)
                @coconut_pod_target.stubs(:resource_paths).returns(resource_paths)
                PodTargetIntegrator.new(@coconut_pod_target).integrate!
                @test_native_target.build_phases.count.should == 2
                @test_native_target.build_phases.map(&:display_name).should == [
                  '[CP] Embed Pods Frameworks',
                  '[CP] Copy Pods Resources',
                ]
                @test_native_target.build_phases[0].input_paths.should == [
                  '${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-frameworks.sh',
                  '${PODS_ROOT}/Vendored/Vendored.framework',
                ]
                @test_native_target.build_phases[0].output_paths.should == [
                  '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/Vendored.framework',
                ]
                @test_native_target.build_phases[1].input_paths.should == [
                  '${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-resources.sh',
                  '${PODS_CONFIGURATION_BUILD_DIR}/TestResourceBundle.bundle',
                ]
                @test_native_target.build_phases[1].output_paths.should == [
                  '${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/TestResourceBundle.bundle',
                ]
              end

              it 'integrates test native target with shell script phases' do
                @coconut_spec.test_specs.first.script_phase = { :name => 'Hello World', :script => 'echo "Hello World"' }
                PodTargetIntegrator.new(@coconut_pod_target).integrate!
                @test_native_target.build_phases.count.should == 3
                @test_native_target.build_phases[2].display_name.should == '[CP-User] Hello World'
                @test_native_target.build_phases[2].shell_script.should == 'echo "Hello World"'
              end

              it 'integrates native target with shell script phases' do
                @coconut_spec.script_phase = { :name => 'Hello World', :script => 'echo "Hello World"' }
                PodTargetIntegrator.new(@coconut_pod_target).integrate!
                @native_target.build_phases.count.should == 1
                @native_target.build_phases[0].display_name.should == '[CP-User] Hello World'
                @native_target.build_phases[0].shell_script.should == 'echo "Hello World"'
              end
            end
          end
        end
      end
    end
  end
end

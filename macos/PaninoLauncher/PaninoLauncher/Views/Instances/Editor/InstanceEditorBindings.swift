import SwiftUI

extension InstanceEditor {
    var manualMemoryBinding: Binding<Int> {
        Binding(
            get: { instance.customMemoryMb ?? instance.memoryMb },
            set: { newValue in
                instance.memoryPolicy = .custom
                instance.customMemoryMb = newValue
                instance.memoryMb = newValue
            }
        )
    }

    var customJvmArgumentsBinding: Binding<String> {
        Binding(
            get: { instance.customJvmArguments },
            set: { newValue in
                instance.customJvmArguments = newValue
                instance.jvmArguments = newValue
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    instance.jvmProfile = .custom
                }
            }
        )
    }
}

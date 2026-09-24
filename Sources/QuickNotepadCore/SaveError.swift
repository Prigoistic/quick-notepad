import Foundation

public enum SaveError: Error, Equatable {
    case appleScriptCompileFailed(String)
    case appleScriptRuntimeFailed(String)

    public var userMessage: String {
        switch self {
        case .appleScriptCompileFailed(let reason), .appleScriptRuntimeFailed(let reason):
            return "Couldn't save: \(reason)"
        }
    }
}

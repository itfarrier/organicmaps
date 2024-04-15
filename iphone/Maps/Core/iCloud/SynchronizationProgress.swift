@objc @objcMembers final class SynchronizationProgress: NSObject {
  var isInProgress: Bool
  var error: SynchronizationError?

  init(isInProgress: Bool, error: SynchronizationError?) {
    self.isInProgress = isInProgress
    self.error = error
  }
}

extension SynchronizationProgress {
  static let notInProgress = SynchronizationProgress(isInProgress: false, error: nil)
  static let inProgress = SynchronizationProgress(isInProgress: true, error: nil)
}

final class SettingsTableViewiCloudSwitchCell: SettingsTableViewSwitchCell {

  override func awakeFromNib() {
    super.awakeFromNib()
    styleDetail()
  }

  @objc
  func updateStateWithError(_ error: Error?) {
    if let error = error as? SynchronizationError {
      switch error {
      case .fileUnavailable, .fileNotUploadedDueToQuota, .ubiquityServerNotAvailable:
        accessoryView = switchButton
      case .iCloudIsNotAvailable, .containerNotFound:
        accessoryView = nil
        accessoryType = .detailButton
      }
      detailTextLabel?.text = error.localizedDescription
    } else {
      detailTextLabel?.text = nil
      accessoryView = switchButton
    }
  }

  private func styleDetail() {
    let detailTextLabelStyle = "regular12:blackSecondaryText"
    detailTextLabel?.setStyleAndApply(detailTextLabelStyle)
  }
}

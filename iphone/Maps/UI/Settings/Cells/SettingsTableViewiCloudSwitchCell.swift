final class SettingsTableViewiCloudSwitchCell: SettingsTableViewSwitchCell {

  override func awakeFromNib() {
    super.awakeFromNib()
    styleDetail()
  }

  override func config(delegate: SettingsTableViewSwitchCellDelegate, title: String, isOn: Bool) {
    super.config(delegate: delegate, title: title, isOn: isOn)
    setSynchronizationEnabled(isOn)
  }

  @objc
  func setSynchronizationEnabled(_ isEnabled: Bool) {
    detailTextLabel?.text = isEnabled ? "Enabling..." : "Disabled"
  }

  @objc
  func setSynchronizationProgress(_ progress: SynchronizationProgress) {
    if let error = progress.error {
      switch error {
      case .fileUnavailable, .fileNotUploadedDueToQuota, .ubiquityServerNotAvailable:
        guard isOn else { return }
        accessoryView = switchButton
      case .iCloudIsNotAvailable, .containerNotFound:
        accessoryView = nil
        accessoryType = .detailButton
      }
      detailTextLabel?.text = error.localizedDescription
    } else {
      guard isOn else { return }
      accessoryView = switchButton
      detailTextLabel?.text = progress.isInProgress ? "Synchronizing…" : "All is up to date"
    }
  }

  private func styleDetail() {
    let detailTextLabelStyle = "regular12:blackSecondaryText"
    detailTextLabel?.setStyleAndApply(detailTextLabelStyle)
  }
}

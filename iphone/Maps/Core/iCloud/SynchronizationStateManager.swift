typealias MetadataItemName = String
typealias LocalContents = [LocalMetadataItem]
typealias CloudContents = [CloudMetadataItem]

protocol SynchronizationStateManager {
  var currentLocalContents: LocalContents { get }
  var currentCloudContents: CloudContents { get }
  var localContentsGatheringIsFinished: Bool { get }
  var cloudContentGatheringIsFinished: Bool { get }
  var isInitialSynchronization: Bool { get set }

  @discardableResult
  func resolveEvent(_ event: IncomingEvent) -> [OutgoingEvent]
  func resetState()
}

enum IncomingEvent {
  case didFinishGatheringLocalContents(LocalContents)
  case didFinishGatheringCloudContents(CloudContents)
  case didUpdateLocalContents(LocalContents)
  case didUpdateCloudContents(CloudContents)
}

enum OutgoingEvent {
  case createLocalItem(CloudMetadataItem)
  case updateLocalItem(CloudMetadataItem)
  case removeLocalItem(CloudMetadataItem)
  case startDownloading(CloudMetadataItem)
  case createCloudItem(LocalMetadataItem)
  case updateCloudItem(LocalMetadataItem)
  case removeCloudItem(LocalMetadataItem)
  case didReceiveError(SynchronizationError)
  case resolveVersionsConflict(CloudMetadataItem)
  case resolveInitialSynchronizationConflict(LocalMetadataItem)
  case didFinishInitialSynchronization
}

final class DefaultSynchronizationStateManager: SynchronizationStateManager {

  // MARK: - Public properties
  private(set) var currentLocalContents: LocalContents = []
  private(set) var currentCloudContents: CloudContents = []
  private(set) var localContentsGatheringIsFinished = false
  private(set) var cloudContentGatheringIsFinished = false
  var isInitialSynchronization: Bool

  init(isInitialSynchronization: Bool) {
    self.isInitialSynchronization = isInitialSynchronization
  }

  // MARK: - Public methods
  @discardableResult
  func resolveEvent(_ event: IncomingEvent) -> [OutgoingEvent] {
    let outgoingEvents: [OutgoingEvent]
    switch event {
    case .didFinishGatheringLocalContents(let contents):
      localContentsGatheringIsFinished = true
      outgoingEvents = resolveDidFinishGathering(localContents: contents, cloudContents: currentCloudContents)
    case .didFinishGatheringCloudContents(let contents):
      cloudContentGatheringIsFinished = true
      outgoingEvents = resolveDidFinishGathering(localContents: currentLocalContents, cloudContents: contents)
    case .didUpdateLocalContents(let contents):
      outgoingEvents = resolveDidUpdateLocalContents(contents)
    case .didUpdateCloudContents(let contents):
      outgoingEvents = resolveDidUpdateCloudContents(contents)
    }
    return outgoingEvents
  }

  func resetState() {
    currentLocalContents.removeAll()
    currentCloudContents.removeAll()
    localContentsGatheringIsFinished = false
    cloudContentGatheringIsFinished = false
  }

  // MARK: - Private methods
  private func resolveDidFinishGathering(localContents: LocalContents, cloudContents: CloudContents) -> [OutgoingEvent] {
    currentLocalContents = localContents
    currentCloudContents = cloudContents
    guard localContentsGatheringIsFinished, cloudContentGatheringIsFinished else { return [] }
    
    var outgoingEvents: [OutgoingEvent]
    switch (localContents.isEmpty, cloudContents.isEmpty) {
    case (true, true):
      outgoingEvents = []
    case (true, false):
      outgoingEvents = cloudContents.notTrashed.map { .createLocalItem($0) }
    case (false, true):
      outgoingEvents = localContents.map { .createCloudItem($0) }
    case (false, false):
      var events = [OutgoingEvent]()
      if isInitialSynchronization {
        events.append(contentsOf: resolveInitialSynchronizationConflicts(localContents: localContents, cloudContents: cloudContents))
      }
      events.append(contentsOf: resolveDidUpdateCloudContents(cloudContents))
      events.append(contentsOf: resolveDidUpdateLocalContents(localContents))
      outgoingEvents = events
    }
    if isInitialSynchronization {
      outgoingEvents.append(.didFinishInitialSynchronization)
      isInitialSynchronization = false
    }
    return outgoingEvents
  }

  private func resolveDidUpdateLocalContents(_ localContents: LocalContents) -> [OutgoingEvent] {
    let itemsToRemoveFromCloudContainer = Self.getItemsToRemoveFromCloudContainer(currentLocalContents: currentLocalContents, newLocalContents: localContents)
    let itemsToCreateInCloudContainer = Self.getItemsToCreateInCloudContainer(cloudContents: currentCloudContents, localContents: localContents)
    let itemsToUpdateInCloudContainer = Self.getItemsToUpdateInCloudContainer(cloudContents: currentCloudContents, localContents: localContents, isInitialSynchronization: isInitialSynchronization)

    var outgoingEvents = [OutgoingEvent]()
    itemsToRemoveFromCloudContainer.forEach { outgoingEvents.append(.removeCloudItem($0)) }
    itemsToCreateInCloudContainer.forEach { outgoingEvents.append(.createCloudItem($0)) }
    itemsToUpdateInCloudContainer.forEach { outgoingEvents.append(.updateCloudItem($0)) }

    currentLocalContents = localContents
    return outgoingEvents
  }

  private func resolveDidUpdateCloudContents(_ cloudContents: CloudContents) -> [OutgoingEvent] {
    var outgoingEvents = [OutgoingEvent]()

    // 1. Handle errors
    let errors = Self.getItemsWithErrors(cloudContents)
    errors.forEach { outgoingEvents.append(.didReceiveError($0)) }

    // 2. Handle merge conflicts
    let itemsWithUnresolvedConflicts = Self.getItemsToResolveConflicts(cloudContents: cloudContents)
    itemsWithUnresolvedConflicts.forEach { outgoingEvents.append(.resolveVersionsConflict($0)) }

    // Merge conflicts should be resolved at first.
    guard itemsWithUnresolvedConflicts.isEmpty else {
      return outgoingEvents
    }

    let itemsToRemoveFromLocalContainer = Self.getItemsToRemoveFromLocalContainer(cloudContents: cloudContents, localContents: currentLocalContents)
    let itemsToCreateInLocalContainer = Self.getItemsToCreateInLocalContainer(cloudContents: cloudContents, localContents: currentLocalContents)
    let itemsToUpdateInLocalContainer = Self.getItemsToUpdateInLocalContainer(cloudContents: cloudContents, localContents: currentLocalContents, isInitialSynchronization: isInitialSynchronization)

    // 3. Handle not downloaded items
    itemsToCreateInLocalContainer.notDownloaded.forEach { outgoingEvents.append(.startDownloading($0)) }
    itemsToUpdateInLocalContainer.notDownloaded.forEach { outgoingEvents.append(.startDownloading($0)) }

    // 4. Handle downloaded items
    itemsToRemoveFromLocalContainer.forEach { outgoingEvents.append(.removeLocalItem($0)) }
    itemsToCreateInLocalContainer.downloaded.forEach { outgoingEvents.append(.createLocalItem($0)) }
    itemsToUpdateInLocalContainer.downloaded.forEach { outgoingEvents.append(.updateLocalItem($0)) }

    currentCloudContents = cloudContents
    return outgoingEvents
  }

  private func resolveInitialSynchronizationConflicts(localContents: LocalContents, cloudContents: CloudContents) -> [OutgoingEvent] {
    let itemsInInitialConflict = localContents.filter { cloudContents.containsByName($0) }
    guard !itemsInInitialConflict.isEmpty else {
      return []
    }
    return itemsInInitialConflict.map { .resolveInitialSynchronizationConflict($0) }
  }

  private static func getItemsToRemoveFromCloudContainer(currentLocalContents: LocalContents, newLocalContents: LocalContents) -> LocalContents {
    currentLocalContents.filter { !newLocalContents.containsByName($0) }
  }

  private static func getItemsToCreateInCloudContainer(cloudContents: CloudContents, localContents: LocalContents) -> LocalContents {
    localContents.reduce(into: LocalContents()) { result, localItem in
      if !cloudContents.containsByName(localItem) {
        result.append(localItem)
      } else if !cloudContents.notTrashed.containsByName(localItem),
                let trashedCloudItem = cloudContents.trashed.firstByName(localItem),
                trashedCloudItem.lastModificationDate < localItem.lastModificationDate {
        // If Cloud .Trash contains item and it's last modification date is less than the local item's last modification date than file should be recreated.
        result.append(localItem)
      }
    }
  }

  private static func getItemsToUpdateInCloudContainer(cloudContents: CloudContents, localContents: LocalContents, isInitialSynchronization: Bool) -> LocalContents {
    guard !isInitialSynchronization else { return [] }
    // Due to the initial sync all conflicted local items will be duplicated with different name and replaced by the cloud items to avoid a data loss.
    return localContents.reduce(into: LocalContents()) { result, localItem in
      if let cloudItem = cloudContents.notTrashed.firstByName(localItem),
         localItem.lastModificationDate > cloudItem.lastModificationDate {
        result.append(localItem)
      }
    }
  }

  private static func getItemsWithErrors(_ cloudContents: CloudContents) -> [SynchronizationError] {
     cloudContents.reduce(into: [SynchronizationError](), { partialResult, cloudItem in
      if let downloadingError = cloudItem.downloadingError, let synchronizationError = SynchronizationError.fromError(downloadingError) {
        partialResult.append(synchronizationError)
      }
      if let uploadingError = cloudItem.uploadingError, let synchronizationError = SynchronizationError.fromError(uploadingError) {
        partialResult.append(synchronizationError)
      }
    })
  }

  private static func getItemsToRemoveFromLocalContainer(cloudContents: CloudContents, localContents: LocalContents) -> CloudContents {
    cloudContents.trashed.reduce(into: CloudContents()) { result, cloudItem in
      // Items shouldn't be removed if newer version of the item isn't in the trash.
      if let notTrashedCloudItem = cloudContents.notTrashed.firstByName(cloudItem), notTrashedCloudItem.lastModificationDate > cloudItem.lastModificationDate {
        return
      }
      if let localItemValue = localContents.firstByName(cloudItem),
         cloudItem.lastModificationDate >= localItemValue.lastModificationDate {
        result.append(cloudItem)
      }
    }
  }

  private static func getItemsToCreateInLocalContainer(cloudContents: CloudContents, localContents: LocalContents) -> CloudContents {
    cloudContents.notTrashed.withUnresolvedConflicts(false).filter { !localContents.containsByName($0) }
  }

  private static func getItemsToUpdateInLocalContainer(cloudContents: CloudContents, localContents: LocalContents, isInitialSynchronization: Bool) -> CloudContents {
    cloudContents.notTrashed.withUnresolvedConflicts(false).reduce(into: CloudContents()) { result, cloudItem in
      if let localItemValue = localContents.firstByName(cloudItem) {
        // Due to the initial sync all conflicted local items will be duplicated with different name and replaced by the cloud items to avoid a data loss.
        if isInitialSynchronization {
          result.append(cloudItem)
        } else if cloudItem.lastModificationDate > localItemValue.lastModificationDate {
          result.append(cloudItem)
        }
      }
    }
  }

  private static func getItemsToResolveConflicts(cloudContents: CloudContents) -> CloudContents {
    cloudContents.notTrashed.withUnresolvedConflicts(true)
  }
}

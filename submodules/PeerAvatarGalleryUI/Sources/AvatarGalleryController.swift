import Foundation
import UIKit
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import AccountContext
import GalleryUI
import LegacyMediaPickerUI
import SaveToCameraRoll

public enum AvatarGalleryEntryId: Hashable {
    case topImage
    case image(MediaId)
    case resource(String)
}

public enum AvatarGalleryEntry: Equatable {
    case topImage([ImageRepresentationWithReference], GalleryItemIndexData?, Data?)
    case image(MediaId, TelegramMediaImageReference?, [ImageRepresentationWithReference], [TelegramMediaImage.VideoRepresentation], Peer?, Int32, GalleryItemIndexData?, MessageId?, Data?)
    
    public var id: AvatarGalleryEntryId {
        switch self {
        case let .topImage(representations, _, _):
            if let last = representations.last {
                return .resource(last.representation.resource.id.uniqueId)
            }
            return .topImage
        case let .image(id, _, representations, _, _, _, _, _, _):
            if let last = representations.last {
                return .resource(last.representation.resource.id.uniqueId)
            }
            return .image(id)
        }
    }
    
    public var representations: [ImageRepresentationWithReference] {
        switch self {
            case let .topImage(representations, _, _):
                return representations
            case let .image(_, _, representations, _, _, _, _, _, _):
                return representations
        }
    }
    
    public var videoRepresentations: [TelegramMediaImage.VideoRepresentation] {
        switch self {
            case .topImage:
                return []
            case let .image(_, _, _, videoRepresentations, _, _, _, _, _):
                return videoRepresentations
        }
    }
    
    public var indexData: GalleryItemIndexData? {
        switch self {
            case let .topImage(_, indexData, _):
                return indexData
            case let .image(_, _, _, _, _, _, indexData, _, _):
                return indexData
        }
    }
    
    public static func ==(lhs: AvatarGalleryEntry, rhs: AvatarGalleryEntry) -> Bool {
        switch lhs {
            case let .topImage(lhsRepresentations, lhsIndexData, lhsImmediateThumbnailData):
                if case let .topImage(rhsRepresentations, rhsIndexData, rhsImmediateThumbnailData) = rhs, lhsRepresentations == rhsRepresentations, lhsIndexData == rhsIndexData, lhsImmediateThumbnailData == rhsImmediateThumbnailData {
                    return true
                } else {
                    return false
                }
            case let .image(lhsId, lhsImageReference, lhsRepresentations, lhsVideoRepresentations, lhsPeer, lhsDate, lhsIndexData, lhsMessageId, lhsImmediateThumbnailData):
                if case let .image(rhsId, rhsImageReference, rhsRepresentations, rhsVideoRepresentations, rhsPeer, rhsDate, rhsIndexData, rhsMessageId, rhsImmediateThumbnailData) = rhs, lhsId == rhsId, lhsImageReference == rhsImageReference, lhsRepresentations == rhsRepresentations, lhsVideoRepresentations == rhsVideoRepresentations, arePeersEqual(lhsPeer, rhsPeer), lhsDate == rhsDate, lhsIndexData == rhsIndexData, lhsMessageId == rhsMessageId, lhsImmediateThumbnailData == rhsImmediateThumbnailData {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class AvatarGalleryControllerPresentationArguments {
    let animated: Bool
    let transitionArguments: (AvatarGalleryEntry) -> GalleryTransitionArguments?
    
    public init(animated: Bool = true, transitionArguments: @escaping (AvatarGalleryEntry) -> GalleryTransitionArguments?) {
        self.animated = animated
        self.transitionArguments = transitionArguments
    }
}

public func initialAvatarGalleryEntries(peer: Peer) -> [AvatarGalleryEntry] {
    var initialEntries: [AvatarGalleryEntry] = []
    if !peer.profileImageRepresentations.isEmpty, let peerReference = PeerReference(peer) {
        initialEntries.append(.topImage(peer.profileImageRepresentations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatar(peer: peerReference, resource: $0.resource)) }), nil, nil))
    }
    return initialEntries
}

public func fetchedAvatarGalleryEntries(account: Account, peer: Peer) -> Signal<[AvatarGalleryEntry], NoError> {
    let initialEntries = initialAvatarGalleryEntries(peer: peer)
    return Signal<[AvatarGalleryEntry], NoError>.single(initialEntries)
    |> then(
        requestPeerPhotos(account: account, peerId: peer.id)
        |> map { photos -> [AvatarGalleryEntry] in
            var result: [AvatarGalleryEntry] = []
            let initialEntries = initialAvatarGalleryEntries(peer: peer)
            if photos.isEmpty {
                result = initialEntries
            } else {
                var index: Int32 = 0
                for photo in photos {
                    let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photos.count))
                    if result.isEmpty, let first = initialEntries.first {
                        result.append(.image(photo.image.imageId, photo.image.reference, first.representations, photo.image.videoRepresentations, peer, photo.date, indexData, photo.messageId, photo.image.immediateThumbnailData))
                    } else {
                        result.append(.image(photo.image.imageId, photo.image.reference, photo.image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.standalone(resource: $0.resource)) }), photo.image.videoRepresentations, peer, photo.date, indexData, photo.messageId, photo.image.immediateThumbnailData))
                    }
                    index += 1
                }
            }
            return result
        }
    )
}

public func fetchedAvatarGalleryEntries(account: Account, peer: Peer, firstEntry: AvatarGalleryEntry) -> Signal<[AvatarGalleryEntry], NoError> {
    let initialEntries = [firstEntry]
    return Signal<[AvatarGalleryEntry], NoError>.single(initialEntries)
    |> then(
        requestPeerPhotos(account: account, peerId: peer.id)
        |> map { photos -> [AvatarGalleryEntry] in
            var result: [AvatarGalleryEntry] = []
            let initialEntries = [firstEntry]
            if photos.isEmpty {
                result = initialEntries
            } else {
                var index: Int32 = 0
                for photo in photos {
                    let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photos.count))
                    if result.isEmpty, let first = initialEntries.first {
                        result.append(.image(photo.image.imageId, photo.image.reference, first.representations, photo.image.videoRepresentations, peer, photo.date, indexData, photo.messageId, photo.image.immediateThumbnailData))
                    } else {
                        result.append(.image(photo.image.imageId, photo.image.reference, photo.image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.standalone(resource: $0.resource)) }), photo.image.videoRepresentations, peer, photo.date, indexData, photo.messageId, photo.image.immediateThumbnailData))
                    }
                    index += 1
                }
            }
            return result
        }
    )
}

public class AvatarGalleryController: ViewController, StandalonePresentableController {
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let context: AccountContext
    private let peer: Peer
    private let sourceHasRoundCorners: Bool
    
    private var presentationData: PresentationData
    
    private let _ready = Promise<Bool>()
    private let animatedIn = ValuePromise<Bool>(true)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private var adjustedForInitialPreviewingLayout = false
    
    private let disposable = MetaDisposable()
    
    private var entries: [AvatarGalleryEntry] = []
    private var centralEntryIndex: Int?
    
    private let centralItemTitle = Promise<String>()
    private let centralItemTitleView = Promise<UIView?>()
    private let centralItemRightBarButtonItems = Promise<[UIBarButtonItem]?>(nil)
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemFooterContentNode = Promise<(GalleryFooterContentNode?, GalleryOverlayContentNode?)>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    private let _hiddenMedia = Promise<AvatarGalleryEntry?>(nil)
    public var hiddenMedia: Signal<AvatarGalleryEntry?, NoError> {
        return self._hiddenMedia.get()
    }
    
    private let replaceRootController: (ViewController, Promise<Bool>?) -> Void
    
    private let editDisposable = MetaDisposable ()
    
    public init(context: AccountContext, peer: Peer, sourceHasRoundCorners: Bool = true, remoteEntries: Promise<[AvatarGalleryEntry]>? = nil, centralEntryIndex: Int? = nil, replaceRootController: @escaping (ViewController, Promise<Bool>?) -> Void, synchronousLoad: Bool = false) {
        self.context = context
        self.peer = peer
        self.sourceHasRoundCorners = sourceHasRoundCorners
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.replaceRootController = replaceRootController
        
        self.centralEntryIndex = centralEntryIndex
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: GalleryController.darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        let backItem = UIBarButtonItem(backButtonAppearanceWithTitle: self.presentationData.strings.Common_Back, target: self, action: #selector(self.donePressed))
        self.navigationItem.leftBarButtonItem = backItem
        
        self.statusBar.statusBarStyle = .White
        
        let remoteEntriesSignal: Signal<[AvatarGalleryEntry], NoError>
        if let remoteEntries = remoteEntries {
            remoteEntriesSignal = remoteEntries.get()
        } else {
            remoteEntriesSignal = fetchedAvatarGalleryEntries(account: context.account, peer: peer)
        }
        
        let entriesSignal: Signal<[AvatarGalleryEntry], NoError> = .single(initialAvatarGalleryEntries(peer: peer)) |> then(remoteEntriesSignal)
        
        let presentationData = self.presentationData
        
        let semaphore: DispatchSemaphore?
        if synchronousLoad {
            semaphore = DispatchSemaphore(value: 0)
        } else {
            semaphore = nil
        }
        
        let syncResult = Atomic<(Bool, (() -> Void)?)>(value: (false, nil))
        
        self.disposable.set(combineLatest(entriesSignal, self.animatedIn.get()).start(next: { [weak self] entries, animatedIn in
            let f: () -> Void = {
                if let strongSelf = self, animatedIn {
                    let isFirstTime = strongSelf.entries.isEmpty
                    
                    var entries = entries
                    if !isFirstTime, let updated = entries.first, case let .image(image) = updated, !image.3.isEmpty, let previous = strongSelf.entries.first, case let .topImage(topImage) = previous {
                        let firstEntry = AvatarGalleryEntry.image(image.0, image.1, topImage.0, image.3, image.4, image.5, image.6, image.7, image.8)
                        entries.remove(at: 0)
                        entries.insert(firstEntry, at: 0)
                    }
                    
                    strongSelf.entries = entries
                    if strongSelf.centralEntryIndex == nil {
                        strongSelf.centralEntryIndex = 0
                    }
                    if strongSelf.isViewLoaded {
                        let canDelete: Bool
                        if strongSelf.peer.id == strongSelf.context.account.peerId {
                            canDelete = true
                        } else if let group = strongSelf.peer as? TelegramGroup {
                            switch group.role {
                                case .creator, .admin:
                                    canDelete = true
                                case .member:
                                    canDelete = false
                            }
                        } else if let channel = strongSelf.peer as? TelegramChannel {
                            canDelete = channel.hasPermission(.changeInfo)
                        } else {
                            canDelete = false
                        }
   
                        strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({ entry in PeerAvatarImageGalleryItem(context: context, peer: peer, presentationData: presentationData, entry: entry, sourceHasRoundCorners: sourceHasRoundCorners, delete: canDelete ? {
                            self?.deleteEntry(entry)
                            } : nil, setMain: { [weak self] in
                                self?.setMainEntry(entry)
                            }, edit: { [weak self] in
                                self?.editEntry(entry)
                        })
                        }), centralItemIndex: strongSelf.centralEntryIndex, synchronous: !isFirstTime)
                        
                        let ready = strongSelf.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak strongSelf] _ in
                            strongSelf?.didSetReady = true
                        }
                        strongSelf._ready.set(ready |> map { true })
                    }
                }
            }
            
            var process = false
            let _ = syncResult.modify { processed, _ in
                if !processed {
                    return (processed, f)
                }
                process = true
                return (true, nil)
            }
            semaphore?.signal()
            if process {
                Queue.mainQueue().async {
                    f()
                }
            }
        }))
        
        if let semaphore = semaphore {
            let _ = semaphore.wait(timeout: DispatchTime.now() + 1.0)
        }
        
        var syncResultApply: (() -> Void)?
        let _ = syncResult.modify { processed, f in
            syncResultApply = f
            return (true, nil)
        }
        
        syncResultApply?()
        
        self.centralItemAttributesDisposable.add(self.centralItemTitle.get().start(next: { [weak self] title in
            if let strongSelf = self {
                strongSelf.navigationItem.setTitle(title, animated: strongSelf.navigationItem.title?.isEmpty ?? true)
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitleView.get().start(next: { [weak self] titleView in
            self?.navigationItem.titleView = titleView
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemRightBarButtonItems.get().start(next: { [weak self] rightBarButtonItems in
            self?.navigationItem.rightBarButtonItems = rightBarButtonItems
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemFooterContentNode.get().start(next: { [weak self] footerContentNode, _ in
            self?.galleryNode.updatePresentationState({
                $0.withUpdatedFooterContentNode(footerContentNode)
            }, transition: .immediate)
        }))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
        self.centralItemAttributesDisposable.dispose()
        self.editDisposable.dispose()
    }
    
    @objc func donePressed() {
        self.dismiss(forceAway: false)
    }
    
    private func dismiss(forceAway: Bool) {
        self.animatedIn.set(false)
        
        var animatedOutNode = true
        var animatedOutInterface = false
        
        let completion = { [weak self] in
            if animatedOutNode && animatedOutInterface {
                self?._hiddenMedia.set(.single(nil))
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            }
        }
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
            if !self.entries.isEmpty {
                if (centralItemNode.index == 0 || !self.sourceHasRoundCorners), let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]), !forceAway {
                    animatedOutNode = false
                    centralItemNode.animateOut(to: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {
                        animatedOutNode = true
                        completion()
                    })
                }
            }
        }
        
        self.galleryNode.animateOut(animateContent: animatedOutNode, completion: {
            animatedOutInterface = true
            completion()
        })
    }
    
    override public func loadDisplayNode() {
        let controllerInteraction = GalleryControllerInteraction(presentController: { [weak self] controller, arguments in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root), with: arguments, blockInteraction: true)
            }
        }, dismissController: { [weak self] in
            self?.dismiss(forceAway: true)
        }, replaceRootController: { [weak self] controller, ready in
            if let strongSelf = self {
                strongSelf.replaceRootController(controller, ready)
            }
        })
        self.displayNode = GalleryControllerNode(controllerInteraction: controllerInteraction)
        self.displayNodeDidLoad()
        
        self.galleryNode.pager.updateOnReplacement = true
        self.galleryNode.statusBar = self.statusBar
        self.galleryNode.navigationBar = self.navigationBar
        
        self.galleryNode.transitionDataForCentralItem = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? AvatarGalleryControllerPresentationArguments {
                    if centralItemNode.index != 0 && strongSelf.sourceHasRoundCorners {
                        return nil
                    }
                    if let transitionArguments = presentationArguments.transitionArguments(strongSelf.entries[centralItemNode.index]) {
                        return (transitionArguments.transitionNode, transitionArguments.addToTransitionSurface)
                    }
                }
            }
            return nil
        }
        self.galleryNode.dismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        let canDelete: Bool
        if self.peer.id == self.context.account.peerId {
            canDelete = true
        } else if let group = self.peer as? TelegramGroup {
            switch group.role {
            case .creator, .admin:
                canDelete = true
            case .member:
                canDelete = false
            }
        } else if let channel = self.peer as? TelegramChannel {
            canDelete = channel.hasPermission(.changeInfo)
        } else {
            canDelete = false
        }
        
        let presentationData = self.presentationData
        self.galleryNode.pager.replaceItems(self.entries.map({ entry in PeerAvatarImageGalleryItem(context: self.context, peer: peer, presentationData: presentationData, entry: entry, sourceHasRoundCorners: self.sourceHasRoundCorners, delete: canDelete ? { [weak self] in
            self?.deleteEntry(entry)
        } : nil, setMain: { [weak self] in
            self?.setMainEntry(entry)
        }, edit: { [weak self] in
            self?.editEntry(entry)
        }) }), centralItemIndex: self.centralEntryIndex)
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var hiddenItem: AvatarGalleryEntry?
                if let index = index {
                    hiddenItem = strongSelf.entries[index]
                    
                    if let node = strongSelf.galleryNode.pager.centralItemNode() {
                        strongSelf.centralItemTitle.set(node.title())
                        strongSelf.centralItemTitleView.set(node.titleView())
                        strongSelf.centralItemRightBarButtonItems.set(node.rightBarButtonItems())
                        strongSelf.centralItemNavigationStyle.set(node.navigationStyle())
                        strongSelf.centralItemFooterContentNode.set(node.footerContent())
                    }
                }
                if strongSelf.didSetReady {
                    strongSelf._hiddenMedia.set(.single(hiddenItem))
                }
            }
        }
        
        let ready = self.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak self] _ in
            self?.didSetReady = true
        }
        self._ready.set(ready |> map { true })
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
            self.centralItemTitle.set(centralItemNode.title())
            self.centralItemTitleView.set(centralItemNode.titleView())
            self.centralItemRightBarButtonItems.set(centralItemNode.rightBarButtonItems())
            self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
            self.centralItemFooterContentNode.set(centralItemNode.footerContent())
            
            if let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]) {
                nodeAnimatesItself = true
                if presentationArguments.animated {
                    self.animatedIn.set(false)
                    centralItemNode.animateIn(from: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {
                        self.animatedIn.set(true)
                    })
                }
                
                self._hiddenMedia.set(.single(self.entries[centralItemNode.index]))
            }
        }
        
        if !self.isPresentedInPreviewingContext() {
            self.galleryNode.setControlsHidden(false, animated: false)
            if let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
                if presentationArguments.animated {
                    self.galleryNode.animateIn(animateContent: !nodeAnimatesItself)
                }
            }
        }
    }
    
    override public func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let itemSize = centralItemNode.contentSize() {
            return itemSize.aspectFitted(layout.size)
        } else {
            return nil
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
        
        if !self.adjustedForInitialPreviewingLayout && self.isPresentedInPreviewingContext() {
            self.adjustedForInitialPreviewingLayout = true
            self.galleryNode.setControlsHidden(true, animated: false)
            if let centralItemNode = self.galleryNode.pager.centralItemNode(), let itemSize = centralItemNode.contentSize() {
                self.preferredContentSize = itemSize.aspectFitted(self.view.bounds.size)
                self.containerLayoutUpdated(ContainerViewLayout(size: self.preferredContentSize, metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
                centralItemNode.activateAsInitial()
            }
        }
    }
    
    private func normalizeEntries(_ entries: [AvatarGalleryEntry]) -> [AvatarGalleryEntry] {
        var updatedEntries: [AvatarGalleryEntry] = []
        let count: Int32 = Int32(entries.count)
        var index: Int32 = 0
        for entry in entries {
            let indexData = GalleryItemIndexData(position: index, totalCount: count)
            if case let .topImage(representations, _, immediateThumbnailData) = entry {
                updatedEntries.append(.topImage(representations, indexData, immediateThumbnailData))
            } else if case let .image(id, reference, representations, videoRepresentations, peer, date, _, messageId, immediateThumbnailData) = entry {
                updatedEntries.append(.image(id, reference, representations, videoRepresentations, peer, date, indexData, messageId, immediateThumbnailData))
            }
            index += 1
        }
        return updatedEntries
    }
    
    private func setMainEntry(_ rawEntry: AvatarGalleryEntry) {
        var entry = rawEntry
        if case .topImage = entry, !self.entries.isEmpty {
            entry = self.entries[0]
        }
        
        switch entry {
            case .topImage:
                if self.peer.id == self.context.account.peerId {
                } else {
                }
            case let .image(_, reference, _, _, _, _, _, messageId, _):
                if self.peer.id == self.context.account.peerId {
                    if let reference = reference {
                        let _ = updatePeerPhotoExisting(network: self.context.account.network, reference: reference).start()
                    }

                    if let index = self.entries.firstIndex(of: entry) {
                        var entries = self.entries
                        
                        let previousFirstEntry = entries.first
                        entries.remove(at: index)
                        entries.remove(at: 0)
                        entries.insert(entry, at: 0)
                        if let previousFirstEntry = previousFirstEntry {
                            entries.insert(previousFirstEntry, at: index)
                        }
                                              
                        let canDelete: Bool
                        if self.peer.id == self.context.account.peerId {
                            canDelete = true
                        } else if let group = self.peer as? TelegramGroup {
                            switch group.role {
                            case .creator, .admin:
                                canDelete = true
                            case .member:
                                canDelete = false
                            }
                        } else if let channel = self.peer as? TelegramChannel {
                            canDelete = channel.hasPermission(.changeInfo)
                        } else {
                            canDelete = false
                        }
                        
                        entries = self.normalizeEntries(entries)
                        
                        self.galleryNode.pager.replaceItems(entries.map({ entry in PeerAvatarImageGalleryItem(context: self.context, peer: peer, presentationData: presentationData, entry: entry, sourceHasRoundCorners: self.sourceHasRoundCorners, delete: canDelete ? { [weak self] in
                            self?.deleteEntry(entry)
                        } : nil, setMain: { [weak self] in
                            self?.setMainEntry(entry)
                        }, edit: { [weak self] in
                            self?.editEntry(entry)
                        }) }), centralItemIndex: 0, synchronous: true)
                        self.entries = entries
                    }
                } else {
//                    if let messageId = messageId {
//                        let _ = deleteMessagesInteractively(account: self.context.account, messageIds: [messageId], type: .forEveryone).start()
//                    }
//
//                    if entry == self.entries.first {
//                        let _ = updatePeerPhoto(postbox: self.context.account.postbox, network: self.context.account.network, stateManager: self.context.account.stateManager, accountPeerId: self.context.account.peerId, peerId: self.peer.id, photo: nil, mapResourceToAvatarSizes: { _, _ in .single([:]) }).start()
//                        self.dismiss(forceAway: true)
//                    } else {
//                        if let index = self.entries.firstIndex(of: entry) {
//                            self.entries.remove(at: index)
//                            self.galleryNode.pager.transaction(GalleryPagerTransaction(deleteItems: [index], insertItems: [], updateItems: [], focusOnItem: index - 1))
//                        }
//                    }
            }
        }
    }
    
    private func editEntry(_ rawEntry: AvatarGalleryEntry) {
        let mediaReference: AnyMediaReference
        if let video = rawEntry.videoRepresentations.last {
            mediaReference = .standalone(media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.dimensions, flags: [])]))
        } else {
            let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: rawEntry.representations.map({ $0.representation }), immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
            mediaReference = .standalone(media: media)
        }
      
        self.editDisposable.set((fetchMediaData(context: self.context, postbox: self.context.account.postbox, mediaReference: mediaReference)
        |> deliverOnMainQueue).start(next: { [weak self] state, isImage in
            guard let strongSelf = self else {
                return
            }
            switch state {
                case let .progress(value):
                    break
                case let .data(data):
                    let screenImage: UIImage?
                    let image: UIImage?
                    let video: URL?
                    if isImage {
                        if let fileData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                            image = UIImage(data: fileData)
                        } else {
                            image = nil
                        }
                        screenImage = image
                        video = nil
                    } else {
                        image = nil
                        video = URL(fileURLWithPath: data.path)
                        screenImage = nil
                    }
                    presentLegacyAvatarEditor(theme: strongSelf.presentationData.theme, screenImage: screenImage, image: image, video: video, present: { [weak self] c, a in
                        if let strongSelf = self {
                            strongSelf.present(c, in: .window(.root), with: a, blockInteraction: true)
                        }
                    }, imageCompletion: { [weak self] image in
                            
                    }, videoCompletion: { [weak self] image, url, adjustments in
                        
                    })
            }
        }))
    }
    
    private func deleteEntry(_ rawEntry: AvatarGalleryEntry) {
        var entry = rawEntry
        if case .topImage = entry, !self.entries.isEmpty {
            entry = self.entries[0]
        }
        
        switch entry {
            case .topImage:
                if self.peer.id == self.context.account.peerId {
                } else {
                    if entry == self.entries.first {
                        let _ = updatePeerPhoto(postbox: self.context.account.postbox, network: self.context.account.network, stateManager: self.context.account.stateManager, accountPeerId: self.context.account.peerId, peerId: self.peer.id, photo: nil, mapResourceToAvatarSizes: { _, _ in .single([:]) }).start()
                        self.dismiss(forceAway: true)
                    } else {
                        if let index = self.entries.firstIndex(of: entry) {
                            self.entries.remove(at: index)
                            self.galleryNode.pager.transaction(GalleryPagerTransaction(deleteItems: [index], insertItems: [], updateItems: [], focusOnItem: index - 1, synchronous: false))
                        }
                    }
                }
            case let .image(_, reference, _, _, _, _, _, messageId, _):
                if self.peer.id == self.context.account.peerId {
                    if let reference = reference {
                        let _ = removeAccountPhoto(network: self.context.account.network, reference: reference).start()
                    }
                    if entry == self.entries.first {
                        self.dismiss(forceAway: true)
                    } else {
                        if let index = self.entries.firstIndex(of: entry) {
                            self.entries.remove(at: index)
                            self.galleryNode.pager.transaction(GalleryPagerTransaction(deleteItems: [index], insertItems: [], updateItems: [], focusOnItem: index - 1, synchronous: false))
                        }
                    }
                } else {
                    if let messageId = messageId {
                        let _ = deleteMessagesInteractively(account: self.context.account, messageIds: [messageId], type: .forEveryone).start()
                    }
                    
                    if entry == self.entries.first {
                        let _ = updatePeerPhoto(postbox: self.context.account.postbox, network: self.context.account.network, stateManager: self.context.account.stateManager, accountPeerId: self.context.account.peerId, peerId: self.peer.id, photo: nil, mapResourceToAvatarSizes: { _, _ in .single([:]) }).start()
                        self.dismiss(forceAway: true)
                    } else {
                        if let index = self.entries.firstIndex(of: entry) {
                            self.entries.remove(at: index)
                            self.galleryNode.pager.transaction(GalleryPagerTransaction(deleteItems: [index], insertItems: [], updateItems: [], focusOnItem: index - 1, synchronous: false))
                        }
                    }
                }
        }
    }
}

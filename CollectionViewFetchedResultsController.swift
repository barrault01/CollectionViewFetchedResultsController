//
//  CollectionViewFetchedResultsController.swift
//
//  Created by Antoine Barrault
//

import UIKit
import CoreData

class CollectionViewFetchedResultsController<T : NSFetchRequestResult> : NSObject, NSFetchedResultsControllerDelegate {

    var onUpdateMethod: ((Void) -> Void)?

    fileprivate lazy var fetchedResults: NSFetchedResultsController<T> = {
        let fetchResultsController =  NSFetchedResultsController(fetchRequest: self.request, managedObjectContext: self.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchResultsController.delegate = self
        return fetchResultsController
    }()

    fileprivate var collectionView: UICollectionView
    fileprivate var request: NSFetchRequest<T>
    fileprivate var managedObjectContext: NSManagedObjectContext
    fileprivate var sectionChanges: [(NSFetchedResultsChangeType, Int)]?
    fileprivate var itemChanges: [(NSFetchedResultsChangeType, [IndexPath])]?
    fileprivate var shouldReloadCollectionView: Bool = false

    init(collectionView: UICollectionView, request: NSFetchRequest<T>, managedObjectContext: NSManagedObjectContext) {
        self.collectionView = collectionView
        self.request = request
        self.managedObjectContext = managedObjectContext
    }

    func performFetch() throws {
        try fetchedResults.performFetch()
    }

    func numberTotalOfObjects  () -> Int {
        return fetchedResults.numberTotalOfObjects()
    }

    func isEmpty() -> Bool {
        return fetchedResults.numberTotalOfObjects() == 0
    }

    func objectAtIndexPath(_ indexPath: IndexPath) -> AnyObject? {
        return self.fetchedResults.object(at: indexPath)
    }

    func objectForSections(_ sectionIndex: Int) -> Int {
        guard let sections = fetchedResults.sections else {
            return 0
        }
        return sections[sectionIndex].numberOfObjects
    }

    @objc func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        sectionChanges = [(NSFetchedResultsChangeType, Int)]()
        itemChanges = [(NSFetchedResultsChangeType, [IndexPath])]()
    }

    @objc func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                          didChange sectionInfo: NSFetchedResultsSectionInfo,
                          atSectionIndex sectionIndex: Int,
                          for type: NSFetchedResultsChangeType) {
        sectionChanges?.append((type, sectionIndex))
    }

    @objc func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                          didChange anObject: Any,
                          at indexPath: IndexPath?,
                          for type: NSFetchedResultsChangeType,
                          newIndexPath: IndexPath?) {

        let change: (NSFetchedResultsChangeType, [IndexPath])
        switch type {
        case .insert:
            if self.collectionView.numberOfSections > 0 {
                if self.collectionView.numberOfItems(inSection: newIndexPath!.section) == 0 {
                    self.shouldReloadCollectionView = true
                    return
                } else {
                    change = (type, [newIndexPath!])
                }
            } else {
                self.shouldReloadCollectionView = true
                return
            }
        case .delete:
            if self.collectionView.numberOfItems(inSection: indexPath!.section) == 1 {
                self.shouldReloadCollectionView = true
                return
            }
            change = (type, [indexPath!])
        case .update:change = (type, [indexPath!])
        case .move:change = (type, [indexPath!, newIndexPath!])
        }
        itemChanges?.append(change)
    }

    @objc func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let sectionChanges = sectionChanges, let itemChanges = itemChanges else {
            return
        }
        //when collectionView is not visible and if it is not the firt insertion or last remotion
        guard shouldReloadCollectionView == false && self.collectionView.window != nil  else {
            self.collectionView.reloadData()
            self.sectionChanges = nil
            self.itemChanges = nil
            if let onUpdateMethod = self.onUpdateMethod {
                onUpdateMethod()
            }
            return
        }

        self.collectionView.performBatchUpdates({
            for change in sectionChanges {
                switch change.0 {
                case .insert:self.collectionView.insertSections(IndexSet(integer: change.1))
                case .delete:self.collectionView.deleteSections(IndexSet(integer: change.1))
                case .move, .update: break
                }
            }
            for change in itemChanges {
                switch change.0 {
                case .insert:self.collectionView.insertItems(at: change.1)
                case .delete:self.collectionView.deleteItems(at: change.1)
                case .update: self.collectionView.reloadItems(at: change.1)
                case .move:self.collectionView.moveItem(at: change.1[0], to: change.1[1])
                }
            }

            }, completion: { _ in
                self.sectionChanges = nil
                self.itemChanges = nil
                if let onUpdateMethod = self.onUpdateMethod {
                    onUpdateMethod()
                }
            }
        )
    }

}

private extension NSFetchedResultsController {

    @objc func numberTotalOfObjects () -> Int {
        guard let sections = self.sections else {
            return 0
        }
        var number = 0
        sections.forEach {number += $0.numberOfObjects}
        return number
    }

}

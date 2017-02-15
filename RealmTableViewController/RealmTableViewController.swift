//
//  RealmTableViewController.swift
//  RealmTableViewControllerExample
//
//  Created by Adam Fish on 10/5/15.
//  Copyright © 2015 Adam Fish. All rights reserved.
//

import UIKit
import RealmSwift
import RBQFetchedResultsController

open class RealmTableViewController: UITableViewController {
  
  // MARK: Properties
  
  /// The name of the Realm Object managed by the grid controller
  @IBInspectable open var entityName: String? {
    didSet {
      self.updateFetchedResultsController()
    }
  }
  
  /// The section name key path used to create the sections. Can be nil if no sections.
  @IBInspectable open var sectionNameKeyPath: String? {
    didSet {
      self.updateFetchedResultsController()
    }
  }
  
  /// The base predicet to to filter the Realm Objects on
  open var basePredicate: NSPredicate? {
    didSet {
      self.updateFetchedResultsController()
    }
  }
  
  /// Array of SortDescriptors
  ///
  /// http://realm.io/docs/cocoa/0.89.2/#ordering-results
  open var sortDescriptors: [SortDescriptor]? {
    didSet {
      
      if let descriptors = self.sortDescriptors {
        
        var rlmSortDescriptors = [RLMSortDescriptor]()
        
        for sortDesc in descriptors {
          
          let rlmSortDesc = RLMSortDescriptor(property: sortDesc.property, ascending: sortDesc.ascending)
          
          rlmSortDescriptors.append(rlmSortDesc)
        }
        
        self.rlmSortDescriptors = rlmSortDescriptors
      }
      
      self.updateFetchedResultsController()
    }
  }
  
  /// The configuration for the Realm in which the entity resides
  ///
  /// Default is [RLMRealmConfiguration defaultConfiguration]
  open var realmConfiguration: Realm.Configuration? {
    set {
      self.internalConfiguration = newValue
      
      self.updateFetchedResultsController()
    }
    get {
      if let configuration = self.internalConfiguration {
        return configuration
      }
      
      return Realm.Configuration.defaultConfiguration
    }
  }
  
  /// The Realm in which the given entity resides in
  open var realm: Realm? {
    if let configuration = self.realmConfiguration {
      return try! Realm(configuration: configuration)
    }
    
    return nil
  }
  
  /// The underlying RBQFetchedResultsController
  open var fetchedResultsController: RBQFetchedResultsController {
    return internalFetchedResultsController
  }
  
  
  // MARK: Object Retrieval
  
  /**
   Retrieve the RLMObject for a given index path
   
   :warning: Returned object is not thread-safe.
   
   :param: indexPath the index path of the object
   
   :returns: RLMObject
   */
  open func objectAtIndexPath<T: Object>(_ type: T.Type, indexPath: IndexPath) -> T? {
    if let anObject: AnyObject = self.fetchedResultsController.object(at: indexPath) as AnyObject? {
      return unsafeBitCast(anObject, to: T.self)
    }
    
    return nil
  }
  
  // MARK: Initializers
  // MARK: Initialization
  
  override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    
    self.baseInit()
  }
  
  override public init(style: UITableViewStyle) {
    super.init(style: style)
    
    self.baseInit()
  }
  
  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    
    self.baseInit()
  }
  
  fileprivate func baseInit() {
    self.internalFetchedResultsController = RBQFetchedResultsController()
    self.internalFetchedResultsController.delegate = self
  }
  
  // MARK: Private Functions
  // fileprivate var viewLoaded: Bool = false
  
  fileprivate var internalConfiguration: Realm.Configuration?
  
  fileprivate var internalFetchedResultsController: RBQFetchedResultsController!
  
  fileprivate var rlmSortDescriptors: [RLMSortDescriptor]?
  
  fileprivate var rlmRealm: RLMRealm? {
    if let realmConfiguration = self.realmConfiguration {
      let configuration = self.toRLMConfiguration(realmConfiguration)
      
      return try! RLMRealm(configuration: configuration)
    }
    
    return nil
  }
  
  fileprivate func updateFetchedResultsController() {
    objc_sync_enter(self)
    if let fetchRequest = self.tableFetchRequest(self.entityName, inRealm: self.rlmRealm, predicate:self.basePredicate) {
      
      self.fetchedResultsController.updateFetchRequest(fetchRequest, sectionNameKeyPath: self.sectionNameKeyPath, andPerformFetch: true)
      
      if self.isViewLoaded {
        self.runOnMainThread({ [weak self] () -> Void in
          self?.tableView.reloadData()
        })
      }
    }
    objc_sync_exit(self)
  }
  
  fileprivate func tableFetchRequest(_ entityName: String?, inRealm realm: RLMRealm?, predicate: NSPredicate?) -> RBQFetchRequest? {
    
    if entityName != nil && realm != nil {
      
      let fetchRequest = RBQFetchRequest(entityName: entityName!, in: realm!, predicate: predicate)
      
      fetchRequest.sortDescriptors = self.rlmSortDescriptors
      
      return fetchRequest
    }
    
    return nil
  }
  
  fileprivate func toRLMConfiguration(_ configuration: Realm.Configuration) -> RLMRealmConfiguration {
    let rlmConfiguration = RLMRealmConfiguration()
    
    if (configuration.fileURL != nil) {
      rlmConfiguration.fileURL = configuration.fileURL
    }
    
    if (configuration.inMemoryIdentifier != nil) {
      rlmConfiguration.inMemoryIdentifier = configuration.inMemoryIdentifier
    }
    
    rlmConfiguration.encryptionKey = configuration.encryptionKey
    rlmConfiguration.readOnly = configuration.readOnly
    rlmConfiguration.schemaVersion = configuration.schemaVersion
    return rlmConfiguration
  }
  
  fileprivate func runOnMainThread(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
      block()
    }
    else {
      DispatchQueue.main.async(execute: { () -> Void in
        block()
      })
    }
  }
}


// MARK: - UIViewController
extension RealmTableViewController {
  open override func viewDidLoad() {
    
    //     self.viewLoaded = true
    
    self.updateFetchedResultsController()
  }
}

// MARK: - UIViewControllerDataSource
extension RealmTableViewController {
  override open func numberOfSections(in tableView: UITableView) -> Int {
    return self.fetchedResultsController.numberOfSections()
  }
  
  override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.fetchedResultsController.numberOfRows(forSectionIndex: section)
  }
  
  override open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return self.fetchedResultsController.titleForHeader(inSection: section)
  }
}


// MARK: - RBQFetchedResultsControllerDelegate
extension RealmTableViewController: RBQFetchedResultsControllerDelegate {
  public func controllerWillChangeContent(_ controller: RBQFetchedResultsController) {
    self.tableView.beginUpdates()
  }
  
  public func controller(_ controller: RBQFetchedResultsController, didChangeSection section: RBQFetchedResultsSectionInfo, at sectionIndex: UInt, for type: NSFetchedResultsChangeType) {
    
    let tableView = self.tableView
    
    switch(type) {
      
    case .insert:
      let insertedSection = IndexSet(integer: Int(sectionIndex))
      tableView?.insertSections(insertedSection, with: UITableViewRowAnimation.fade)
    case .delete:
      let deletedSection = IndexSet(integer: Int(sectionIndex))
      tableView?.deleteSections(deletedSection, with: UITableViewRowAnimation.fade)
    default:
      break
    }
  }
  
  public func controller(_ controller: RBQFetchedResultsController, didChange anObject: RBQSafeRealmObject, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    
    let tableView = self.tableView
    
    switch(type) {
      
    case .insert:
      tableView?.insertRows(at: [newIndexPath!], with: UITableViewRowAnimation.fade)
    case .delete:
      tableView?.deleteRows(at: [indexPath!], with: UITableViewRowAnimation.fade)
    case .update:
      if tableView?.indexPathsForVisibleRows?.contains(indexPath!) == true {
        tableView?.reloadRows(at: [indexPath!], with: UITableViewRowAnimation.fade)
      }
    case .move:
      tableView?.deleteRows(at: [indexPath!], with: UITableViewRowAnimation.fade)
      tableView?.insertRows(at: [newIndexPath!], with: UITableViewRowAnimation.fade)
    }
  }
  
  public func controllerDidChangeContent(_ controller: RBQFetchedResultsController) {
    self.tableView.endUpdates()
  }
}

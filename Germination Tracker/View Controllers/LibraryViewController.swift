//
//  ViewController.swift
//  Germination Tracker
//
//  Created by Joshua on 9/20/19.
//  Copyright © 2019 Joshua Cook. All rights reserved.
//

import UIKit
import os
import ChameleonFramework


/**
 A table view controller for all of the sowings.
 */
class LibraryViewController: UITableViewController {

    /// String to reference reusbale cells.
    private let reusableCellIdentifier = "PlantCell"
    
    /// The sorting system for the library's cells.
    private var sortOption: SortOption = {
        let defaults = UserDefaults.standard
        var option: SortOption!
        if let optionString = defaults.string(forKey: "librarySortOption") {
            option = SortOption(rawValue: optionString)
        } else {
            option = SortOption.byPlantName
        }
        return option
        }() {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(sortOption.rawValue, forKey: "librarySortOption")
            sectionManager.sortOption = self.sortOption
            reloadData()
        }
    }
    
    /// The object that handles the plants array.
    /// This object gets passed to several child view controllers.
    var plantsManager = PlantsArrayManager()
    
    
    var sectionManager: LibraryTableViewDataManager!
    
    
    override func viewDidLoad() {
        os_log("Library view controller view did load.", log: Log.libraryVC, type: .info)
        
        super.viewDidLoad()
        
        // Navigation bar button to sort (left) or add a new plant (right).
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Sort", style: .plain, target: self, action: #selector(changeSortOption))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewPlant))
        
        // Set up title.
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "Garden"
        
        // Setup the data manager.
        sectionManager = LibraryTableViewDataManager(plantsManager: plantsManager, sortOption: sortOption)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        os_log("Library view controller view will appear.", log: Log.libraryVC, type: .info)
        
        super.viewWillAppear(animated)
        
        // Save plants and reload the table view's data every time the view will appear.
        plantsManager.savePlants()
        
        // Organize the cells.
        reloadData()
    }
    
    
    func reloadData() {
        sectionManager.organizeSections()
        tableView.reloadData()
    }

    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionManager.sections[section].sectionName
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reusableCellIdentifier, for: indexPath) as! LibraryTableViewCell
        
        // Tell the cell if it is part of a group or not
        cell.cellsAreGrouped = (sortOption == .byActive || sortOption == .byPlantName)
        
        // Get plant and set let the cell configure itself for a plant object.
        let section = sectionManager.sections[indexPath.section]
        let plant = section.rows[indexPath.row]
        cell.configureCellFor(plant)
        return cell
    }

    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionManager.sections.count
    }
    
    
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sectionManager.sections[section].rows.count
    }
    
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    
    
    @objc private func changeSortOption() {
        let ac = UIAlertController(title: "Sort Plants", message: "Change the sorting method of the plants.", preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "By plant name", style: .default) { [weak self] _ in
            if self?.sortOption != .byPlantName { self?.sortOption = .byPlantName }
        })
        ac.addAction(UIAlertAction(title: "By date (descending)", style: .default) { [weak self] _ in
            if self?.sortOption != .byDateDescending { self?.sortOption = .byDateDescending }
        })
        ac.addAction(UIAlertAction(title: "By date (ascending)", style: .default) { [weak self] _ in
            if self?.sortOption != .byDateAscending { self?.sortOption = .byDateAscending }
        })
        ac.addAction(UIAlertAction(title: "Into Active and Archived", style: .default) { [weak self] _ in
            if self?.sortOption != .byActive { self?.sortOption = .byActive }
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    
    /// Add a new plant object.
    /// This opens a alert controller with a text field for the user to enter the new plant's name.
    /// It then saves the new plant and opens its detail view.
    @objc private func addNewPlant() {
        os_log("Adding a new plant.", log: Log.libraryVC, type: .info)
        
        let ac = UIAlertController(title: "New plant name", message: "Enter the name of the new plant you are sowing.", preferredStyle: .alert)
        ac.addTextField()
        ac.addAction(UIAlertAction(title: "Submit", style: .default) { [weak self] _ in
            // Make and save new plant.
            self?.plantsManager.newPlant(named: ac.textFields![0].text ?? "")
            self?.plantsManager.savePlants()
            
            // Reload the table view with the new plant and open its detail view.
            self?.tableView.reloadData()
            let indexPath = IndexPath(row: (self?.plantsManager.plants.count)! - 1, section: 0)
                        
            self?.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
            self?.performSegue(withIdentifier: "gardenToDetail", sender: self)
            self?.tableView.deselectRow(at: indexPath, animated: true)
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(ac, animated: true)
    }
    
    
    /// Make a new plant with the name of another plant.
    /// - parameter plant: Plant object to use as the template for the copy.
    private func addPlant(copiedFromPlant plant: Plant) {
        os_log("User is adding a new plant.", log: Log.libraryVC, type: .info)
        plantsManager.newPlant(named: plant.name)
        sectionManager.organizeSections()
        let indexPath = sectionManager.indexPathForPlant(plant)
        tableView.insertRows(at: [indexPath], with: .fade)
    }
    
    
    /// Change the name of a plant.
    /// This function presents an alert controller with a text field for the user to enter the new name of the plant.
    /// - parameter indexPath: The index of the plant to change the name of.
    private func editPlantName(atIndex indexPath: IndexPath) {
        os_log("User is editing the name of a plant.", log: Log.libraryVC, type: .info)
        let ac = UIAlertController(title: "Rename plant", message: nil, preferredStyle: .alert)
        ac.addTextField { [weak self] tf in
            if let plant = self?.sectionManager.plantForRowAt(indexPath: indexPath) {
                tf.text = plant.name
                tf.selectedTextRange = tf.textRange(from: tf.endOfDocument, to: tf.endOfDocument)
                tf.clearButtonMode = .always
            }
        }
        ac.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            if let plant = self?.sectionManager.plantForRowAt(indexPath: indexPath),
                let text = ac.textFields![0].text,
                let tv = self?.tableView,
                let manager = self?.plantsManager,
                let sectionManager = self?.sectionManager {
                
                // Nothing to update
                if plant.name == text { return }
                
                // Get the number of plants that were in the section before the change (used during table view update).
                let numberOfPlantsInOldSection = sectionManager.numberOfPlants(inSection: indexPath.section)
                
                // Update the plant, save, and reorganize the table view sections.
                plant.name = text
                manager.savePlants()
                sectionManager.organizeSections()
                let newIndexPath = sectionManager.indexPathForPlant(plant)
                
                // Batch updates to table view.
                tv.performBatchUpdates({
                    // Remove section if it only had one plant left.
                    if numberOfPlantsInOldSection == 1 {
                        tv.deleteSections(IndexSet(integer: indexPath.section), with: .left)
                    }
                    // Insert section if it only has one plant after the move.
                    // This means it is a new section.
                    if sectionManager.numberOfPlants(inSection: newIndexPath.section) == 1 {
                        tv.insertSections(IndexSet(integer: newIndexPath.section), with: .left)
                    }
                    
                    // Delete old and insert new rows.
                    tv.deleteRows(at: [indexPath], with: .left)
                    tv.insertRows(at: [newIndexPath], with: .left)
                })
                os_log("User has change the name of a plant.", log: Log.libraryVC, type: .info)
            }
        }))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(ac, animated: true)
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Specific segue instructions for passing to a `PagingViewController` for a plant.
        if let destinationVC = segue.destination as? PagingViewController,
            let indexPath = tableView.indexPathForSelectedRow {
            destinationVC.plant = plantsManager.plants[indexPath.row]
            destinationVC.plantsManager = self.plantsManager
        }
    }
    
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            os_log("User is deleting the cell at section %d, row %d", log: Log.libraryVC, type: .info, indexPath.section, indexPath.row)
            let plant = sectionManager.plantForRowAt(indexPath: indexPath)
            let numberOfPlantsInSection = sectionManager.numberOfPlants(inSection: indexPath.section)
            plantsManager.remove(plant)
            plantsManager.savePlants()
            sectionManager.organizeSections()
            if numberOfPlantsInSection == 1 {
                tableView.deleteSections(IndexSet(integer: indexPath.section), with: .left)
            } else {
                tableView.deleteRows(at: [indexPath], with: .left)
            }
        }
    }
    
    
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // An action to copy the plant into a new `Plant` object.
        let copyAction = UIContextualAction(style: .normal, title: "Copy") { [weak self] (ac: UIContextualAction, view: UIView, success: (Bool) -> Void) in
            self?.addPlant(copiedFromPlant: self?.sectionManager.plantForRowAt(indexPath: indexPath) ?? Plant(name: ""))
            success(true)
        }
        if #available(iOS 13, *) {
            copyAction.backgroundColor = .systemGreen
        } else {
            copyAction.backgroundColor = FlatGreen()
        }

        // An action to edit the name of a plant.
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] (ac: UIContextualAction, view: UIView, success: (Bool) -> Void) in
            self?.editPlantName(atIndex: indexPath)
            success(true)
        }
        if #available(iOS 13, *) {
            editAction.backgroundColor = .systemBlue
        } else {
            editAction.backgroundColor = FlatBlue()
        }
        
        return UISwipeActionsConfiguration(actions: [editAction, copyAction])
    }


}


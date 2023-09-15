//
// Copyright (C) 2017 Advanced Card Systems Ltd. All rights reserved.
//
// This software is the confidential and proprietary information of Advanced
// Card Systems Ltd. ("Confidential Information").  You shall not disclose such
// Confidential Information and shall use it only in accordance with the terms
// of the license agreement you entered into with ACS.
//

import UIKit

/// The `FileListViewController` class shows files for selection.
///
/// - Author:  Godfrey Chung
/// - Version: 1.0
/// - Date:    13 Dec 2017
class FileListViewController: UITableViewController {

    /// The array of filenames
    var filenames = [String]()

    /// The selected filename
    var filename: String?

    /// The delegate object you want to receive file list view controller
    /// events.
    var delegate: FileListViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        return filenames.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // Show the filename on the cell.
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell",
                                                 for: indexPath)
        cell.textLabel?.text = filenames[indexPath.row]
        if let filename = filename {
            if filename == filenames[indexPath.row] {
                cell.accessoryType = .checkmark
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: false)

        // Return if the filename is selected.
        var foundIndex = -1
        if let filename = filename,
            let index = filenames.firstIndex(of: filename) {

            if (index == indexPath.row) {
                return
            }

            foundIndex = index
        }

        // Set the check mark on the filename.
        if let newCell = tableView.cellForRow(at: indexPath) {
            if newCell.accessoryType == .none {

                newCell.accessoryType = .checkmark
                filename = filenames[indexPath.row]
                delegate?.fileListViewController(self, didSelectFile: filename!)
            }
        }

        // Reset the check mark on the previous filename.
        if (foundIndex >= 0) {

            let oldIndexPath = IndexPath(row: foundIndex, section: 0)
            if let oldCell = tableView.cellForRow(at: oldIndexPath) {
                if oldCell.accessoryType == .checkmark {
                    oldCell.accessoryType = .none
                }
            }
        }
    }
}

/// The `FileListViewControllerDelegate` protocol defines the methods that a
/// delegate of a `FileListViewController` object must adopt.
protocol FileListViewControllerDelegate {

    /// Invoked when the file is selected.
    ///
    /// - Parameters:
    ///   - fileListViewController: the file list view controller
    ///   - filename: the selected filename
    func fileListViewController(
        _ fileListViewController: FileListViewController,
        didSelectFile filename: String)
}

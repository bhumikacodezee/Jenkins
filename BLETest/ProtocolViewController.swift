//
// Copyright (C) 2017 Advanced Card Systems Ltd. All rights reserved.
//
// This software is the confidential and proprietary information of Advanced
// Card Systems Ltd. ("Confidential Information").  You shall not disclose such
// Confidential Information and shall use it only in accordance with the terms
// of the license agreement you entered into with ACS.
//

import UIKit

/// The `ProtocolViewController` class shows protocols for selection.
///
/// - Author:  Godfrey Chung
/// - Version: 1.0
/// - Date:    11 Dec 2017
class ProtocolViewController: UITableViewController {

    /// The array of selected protcols
    var protocols = [ true, true ]

    /// The delegate object you want to receive protocol view controller events.
    var delegate: ProtocolViewControllerDelegate?

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

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let protocolStrings = [ "T=0", "T=1" ]
        let cellId = protocolStrings[indexPath.row]
        var cell = tableView.dequeueReusableCell(withIdentifier: cellId)
        if (cell == nil) {
            cell = UITableViewCell(style: .default, reuseIdentifier: cellId)
        }

        // Show the protocol on the cell.
        cell!.textLabel?.text = cellId

        // Set the check mark if the protocol is selected.
        if protocols[indexPath.row] {
            cell!.accessoryType = .checkmark
        }

        return cell!
    }

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: false)

        if let cell = tableView.cellForRow(at: indexPath) {
            if cell.accessoryType == .none {

                // Select the protocol.
                cell.accessoryType = .checkmark
                protocols[indexPath.row] = true
                delegate?.protocolViewController(self,
                                                 didSelectProtocols: protocols)

            } else if cell.accessoryType == .checkmark {

                // Deselect the protocol.
                cell.accessoryType = .none
                protocols[indexPath.row] = false
                delegate?.protocolViewController(self,
                                                 didSelectProtocols: protocols)
            }
        }
    }
}

/// The `ProtocolViewControllerDelegate` protocol defines the methods that a
/// delegate of a `ProtocolViewController` object must adopt.
protocol ProtocolViewControllerDelegate {

    /// Invoked when the protocol is selected.
    ///
    /// - Parameters:
    ///   - protocolViewController: the protocol view controller
    ///   - protocols: the array of selected protocols
    func protocolViewController(
        _ protocolViewController: ProtocolViewController,
        didSelectProtocols protocols: [Bool])
}

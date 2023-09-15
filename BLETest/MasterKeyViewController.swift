//
// Copyright (C) 2018 Advanced Card Systems Ltd. All rights reserved.
//
// This software is the confidential and proprietary information of Advanced
// Card Systems Ltd. ("Confidential Information").  You shall not disclose such
// Confidential Information and shall use it only in accordance with the terms
// of the license agreement you entered into with ACS.
//

import UIKit

/// The `MasterKeyViewController` class shows the master key settings of card
/// terminal.
///
/// - Author:  Godfrey Chung
/// - Version: 1.0
/// - Date:    26 Jun 2018
/// - Since:   0.3
class MasterKeyViewController: UITableViewController {

    @IBOutlet weak var defaultKeySwitch: UISwitch!
    @IBOutlet weak var newKeyTextField: UITextField!

    /// `true` if the default key is used, otherwise `false`.
    var isDefaultKeyUsed = true

    /// The new key
    var newKey = ""

    /// The delegate object you want to receive master key view controller
    /// events.
    var delegate: MasterKeyViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem

        defaultKeySwitch.setOn(isDefaultKeyUsed, animated: false)
        defaultKeySwitch.addTarget(
            self,
            action: #selector(defaultKeyChanged(sender:)),
            for: UIControl.Event.valueChanged)

        newKeyTextField.text = newKey
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func defaultKeyChanged(sender: UISwitch) {

        if sender == defaultKeySwitch {

            isDefaultKeyUsed = sender.isOn
            delegate?.masterKeyViewController(
                self,
                didUpdateSettings: isDefaultKeyUsed,
                newKey: newKey)
        }
    }
}

// MARK: - UITextFieldDelegate
extension MasterKeyViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        if textField == newKeyTextField {
            textField.resignFirstResponder()
        }

        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {

        if textField == newKeyTextField {
            if let text = textField.text {

                newKey = Hex.toHexString(
                    buffer: Hex.toByteArray(hexString: text))
                delegate?.masterKeyViewController(
                    self,
                    didUpdateSettings: isDefaultKeyUsed,
                    newKey: newKey)
            }
        }
    }
}

/// The `MasterKeyViewControllerDelegate` protocol defines the methods that a
/// delegate of a `MasterKeyViewController` object must adopt.
protocol MasterKeyViewControllerDelegate {

    /// Invoked when the settings are updated.
    ///
    /// - Parameters:
    ///   - masterKeyViewController: the master key view controller
    ///   - isDefaultKeyUsed: `true` to use the default key, otherwise `false`.
    ///   - newKey: the new key
    func masterKeyViewController(
        _ masterKeyViewController: MasterKeyViewController,
        didUpdateSettings isDefaultKeyUsed: Bool,
        newKey: String)
}

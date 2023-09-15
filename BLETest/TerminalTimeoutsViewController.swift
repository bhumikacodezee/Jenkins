//
// Copyright (C) 2019 Advanced Card Systems Ltd. All rights reserved.
//
// This software is the confidential and proprietary information of Advanced
// Card Systems Ltd. ("Confidential Information").  You shall not disclose such
// Confidential Information and shall use it only in accordance with the terms
// of the license agreement you entered into with ACS.
//

import UIKit
import ACSSmartCardIO

/// The `TerminalTimeoutsViewController` class shows the timeouts settings of
/// card terminal.
///
/// - Author:  Godfrey Chung
/// - Version: 1.0
/// - Date:    23 Sep 2019
/// - Since:   0.5
class TerminalTimeoutsViewController: UITableViewController {

    @IBOutlet weak var defaultTimeoutSwitch: UISwitch!
    @IBOutlet weak var connectionTimeoutTextField: UITextField!
    @IBOutlet weak var powerTimeoutTextField: UITextField!
    @IBOutlet weak var protocolTimeoutTextField: UITextField!
    @IBOutlet weak var apduTimeoutTextField: UITextField!
    @IBOutlet weak var controlTimeoutTextField: UITextField!

    /// The timeout for connecting the device in milliseconds.
    var connectionTimeout = TerminalTimeouts.defaultTimeout

    /// The timeout for resetting or powering down the card in milliseconds.
    var powerTimeout = TerminalTimeouts.defaultTimeout

    /// The timeout for setting the protocol in milliseconds.
    var protocolTimeout = TerminalTimeouts.defaultTimeout

    /// The timeout for transmitting APDU in milliseconds.
    var apduTimeout = TerminalTimeouts.defaultTimeout

    /// The timeout for transmitting control command in milliseconds.
    var controlTimeout = TerminalTimeouts.defaultTimeout

    /// The delegate object you want to receive terminal timeouts
    /// view controller events.
    var delegate: TerminalTimeoutsViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem

        defaultTimeoutSwitch.isOn =
            connectionTimeout == TerminalTimeouts.defaultTimeout
            && powerTimeout == TerminalTimeouts.defaultTimeout
            && protocolTimeout == TerminalTimeouts.defaultTimeout
            && apduTimeout == TerminalTimeouts.defaultTimeout
            && controlTimeout == TerminalTimeouts.defaultTimeout
        defaultTimeoutSwitch.addTarget(
            self,
            action: #selector(defaultTimeoutChanged(sender:)),
            for: UIControl.Event.valueChanged)

        connectionTimeoutTextField.isEnabled = !defaultTimeoutSwitch.isOn
        powerTimeoutTextField.isEnabled = !defaultTimeoutSwitch.isOn
        protocolTimeoutTextField.isEnabled = !defaultTimeoutSwitch.isOn
        apduTimeoutTextField.isEnabled = !defaultTimeoutSwitch.isOn
        controlTimeoutTextField.isEnabled = !defaultTimeoutSwitch.isOn

        connectionTimeoutTextField.text = String(connectionTimeout)
        powerTimeoutTextField.text = String(powerTimeout)
        protocolTimeoutTextField.text = String(protocolTimeout)
        apduTimeoutTextField.text = String(apduTimeout)
        controlTimeoutTextField.text = String(controlTimeout)
    }

    @IBAction func defaultTimeoutChanged(sender: UISwitch) {

        if sender == defaultTimeoutSwitch {

            connectionTimeoutTextField.isEnabled = !sender.isOn
            powerTimeoutTextField.isEnabled = !sender.isOn
            protocolTimeoutTextField.isEnabled = !sender.isOn
            apduTimeoutTextField.isEnabled = !sender.isOn
            controlTimeoutTextField.isEnabled = !sender.isOn

            if sender.isOn {

                connectionTimeout = TerminalTimeouts.defaultTimeout
                powerTimeout = TerminalTimeouts.defaultTimeout
                protocolTimeout = TerminalTimeouts.defaultTimeout
                apduTimeout = TerminalTimeouts.defaultTimeout
                controlTimeout = TerminalTimeouts.defaultTimeout

                connectionTimeoutTextField.text = String(connectionTimeout)
                powerTimeoutTextField.text = String(powerTimeout)
                protocolTimeoutTextField.text = String(protocolTimeout)
                apduTimeoutTextField.text = String(apduTimeout)
                controlTimeoutTextField.text = String(controlTimeout)
            }

            delegate?.terminalTimeoutsViewController(
                self,
                didUpdateSettings: connectionTimeout,
                powerTimeout: powerTimeout,
                protocolTimeout: protocolTimeout,
                apduTimeout: apduTimeout,
                controlTimeout: controlTimeout)
        }
    }
}

// MARK: - UITextFieldDelegate
extension TerminalTimeoutsViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        if textField == connectionTimeoutTextField
            || textField == powerTimeoutTextField
            || textField == protocolTimeoutTextField
            || textField == apduTimeoutTextField
            || textField == controlTimeoutTextField {
            textField.resignFirstResponder()
        }

        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {

        if let timeout = Int(textField.text ?? "") {

            if textField == connectionTimeoutTextField {
                connectionTimeout = timeout
            } else if textField == powerTimeoutTextField {
                powerTimeout = timeout
            } else if textField == protocolTimeoutTextField {
                protocolTimeout = timeout
            } else if textField == apduTimeoutTextField {
                apduTimeout = timeout
            } else if textField == controlTimeoutTextField {
                controlTimeout = timeout
            } else {
                return
            }

            delegate?.terminalTimeoutsViewController(
                self,
                didUpdateSettings: connectionTimeout,
                powerTimeout: powerTimeout,
                protocolTimeout: protocolTimeout,
                apduTimeout: apduTimeout,
                controlTimeout: controlTimeout)
        }
    }
}

/// The `TerminalTimeoutsViewControllerDelegate` protocol defines the methods
/// that a delegate of a `TerminalTimeoutsViewController` object must adopt.
protocol TerminalTimeoutsViewControllerDelegate {

    /// Invoked when the settings are updated.
    ///
    /// - Parameters:
    ///   - terminalTimeoutsViewController: the terminal timeouts view
    ///     controller
    ///   - connectionTimeout: the connection timeout
    ///   - powerTimeout: the power timeout
    ///   - protocolTimeout: the protocol timeout
    ///   - apduTimeout: the APDU timeout
    ///   - controlTimeout: the control timeout
    func terminalTimeoutsViewController(
        _ terminalTimeoutsViewController: TerminalTimeoutsViewController,
        didUpdateSettings connectionTimeout: Int,
        powerTimeout: Int,
        protocolTimeout: Int,
        apduTimeout: Int,
        controlTimeout: Int)
}

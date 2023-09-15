//
// Copyright (C) 2017 Advanced Card Systems Ltd. All rights reserved.
//
// This software is the confidential and proprietary information of Advanced
// Card Systems Ltd. ("Confidential Information").  You shall not disclose such
// Confidential Information and shall use it only in accordance with the terms
// of the license agreement you entered into with ACS.
//

import Foundation
import UIKit
import SmartCardIO
import ACSSmartCardIO

/// The `MainViewController` class is the main screen that demonstrates the
/// functionality of Bluetooth card terminal.
///
/// - Author:  Godfrey Chung
/// - Version: 1.0
/// - Date:    9 Dec 2017
class MainViewController: UITableViewController {

    @IBOutlet weak var terminalLabel: UILabel!
    @IBOutlet weak var masterKeyLabel: UILabel!
    @IBOutlet weak var terminalTimeoutsLabel: UILabel!
    @IBOutlet weak var protocolLabel: UILabel!
    @IBOutlet weak var controlCodeTextField: UITextField!
    @IBOutlet weak var scriptFileLabel: UILabel!
    @IBOutlet weak var showCardStateLabel: UILabel!
    @IBOutlet weak var logTextView: UITextView!

    static let keyPrefT0GetResponse = "pref_t0_get_response"
    static let keyPrefT1GetResponse = "pref_t1_get_response"
    static let keyPrefT1StripLe = "pref_t1_strip_le"

    static let keyPrefUseDefaultKey = "pref_use_default_key"
    static let keyPrefNewKey = "pref_new_key"
    static let keyPrefConnectionTimeout = "pref_connection_timeout"
    static let keyPrefPowerTimeout = "pref_power_timeout"
    static let keyPrefProtocolTimeout = "pref_protocol_timeout"
    static let keyPrefApduTimeout = "pref_apdu_timeout"
    static let keyPrefControlTimeout = "pref_control_timeout"

    let manager = BluetoothSmartCard.shared.manager
    let factory = BluetoothSmartCard.shared.factory
    weak var terminalListViewController: TerminalListViewController?
    var terminal: CardTerminal?
    var protocols = [ true, true ]
    var filename: String?
    var logger: Logger!
    let cardStateMonitor = CardStateMonitor.shared
    var firstRun = true
    var cardName : String = ""
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        // Set the delegate.
        manager.delegate = self
        cardStateMonitor.delegate = self

        // Initialize the text.
        terminalLabel.text = ""
        masterKeyLabel.text = ""
        terminalTimeoutsLabel.text = ""
        protocolLabel.text = "T=0 or T=1"
        controlCodeTextField.text = String(BluetoothTerminalManager.ioctlEscape)
        scriptFileLabel.text = ""

        // Initialize the logger.
        logger = Logger(textView: logTextView)

        // Set default values.
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            MainViewController.keyPrefT0GetResponse: true,
            MainViewController.keyPrefT1GetResponse: true,
            MainViewController.keyPrefT1StripLe: false])

        // Register for defaults changed.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil)

        // Load the settings.
        loadSettings()
    }

    @objc func defaultsChanged(notification: NSNotification) {
        loadSettings()
    }

    /// Loads the settings.
    func loadSettings() {

        logger.logMsg("Loading the settings...")

        let defaults = UserDefaults.standard
        TransmitOptions.t0GetResponse = defaults.bool(
            forKey: MainViewController.keyPrefT0GetResponse)
        TransmitOptions.t1GetResponse = defaults.bool(
            forKey: MainViewController.keyPrefT1GetResponse)
        TransmitOptions.t1StripLe = defaults.bool(
            forKey: MainViewController.keyPrefT1StripLe)

        logger.logMsg("Transmit Options")
        logger.logMsg("- t0GetResponse: \(TransmitOptions.t0GetResponse)")
        logger.logMsg("- t1GetResponse: \(TransmitOptions.t1GetResponse)")
        logger.logMsg("- t1StripLe: \(TransmitOptions.t1StripLe)")
    }

    deinit {

        // Unregister the observer on iOS < 9.0 and macOS < 10.11.
        if #available(iOS 9.0, macOS 10.11, *) {
        } else {
            NotificationCenter.default.removeObserver(self)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func shouldPerformSegue(withIdentifier identifier: String,
                                     sender: Any?) -> Bool {

        if identifier == "SetMasterKey"
            || identifier == "SetTerminalTimeouts" {

            // Check the selected card terminal.
            if terminal == nil {

                logger.logMsg("Error: Card terminal not selected")
                return false
            }
        }

        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        if let identifier = segue.identifier {
            switch identifier {

            case "ScanTerminals":
                if let navigationViewController = segue.destination
                    as? UINavigationController,

                    let topViewController = navigationViewController
                        .topViewController,

                    let terminalListViewController = topViewController
                        as? TerminalListViewController {

                    // Show the selected card terminal.
                    terminalListViewController.terminal = terminal

                    // Set the manager for scan.
                    terminalListViewController.manager = manager

                    // Store the terminal list view controller.
                    self.terminalListViewController = terminalListViewController
                }

            case "ListTerminals":
                if let terminalListViewController = segue.destination
                    as? TerminalListViewController {

                    // List terminals from factory.
                    do {
                        terminalListViewController.terminals = try factory
                            .terminals().list()
                    } catch {
                        logger.logMsg("ListTerminals: "
                            + error.localizedDescription)
                    }

                    // Show the selected card terminal.
                    terminalListViewController.terminal = terminal
                    terminalListViewController.delegate = self
                }

            case "ShowProtocol":
                if let protocolViewController = segue.destination
                    as? ProtocolViewController {

                    // Show the selected protocol.
                    protocolViewController.protocols = protocols
                    protocolViewController.delegate = self
                }

            case "ListFiles":
                if let fileListViewController = segue.destination
                    as? FileListViewController {

                    // List files from documents directory.
                    let paths = NSSearchPathForDirectoriesInDomains(
                        .documentDirectory, .userDomainMask, true)
                    let documentsDirectory = paths[0]
                    if let filenames = try? FileManager.default
                        .contentsOfDirectory(atPath: documentsDirectory) {

                        fileListViewController.filenames = filenames
                        fileListViewController.filename = filename
                        fileListViewController.delegate = self
                    }
                }

            case "SetMasterKey":
                if let masterKeyViewController = segue.destination
                    as? MasterKeyViewController,
                    let terminal = terminal,
                    let defaults = UserDefaults(suiteName: "com.acs.BLETest."
                        + terminal.name) {

                    // Load the settings.`
                    let enabled = defaults.bool(
                        forKey: MainViewController.keyPrefUseDefaultKey)
                    let newKey = defaults.string(
                        forKey: MainViewController.keyPrefNewKey)

                    masterKeyViewController.isDefaultKeyUsed = enabled
                    masterKeyViewController.newKey = newKey ?? ""
                    masterKeyViewController.delegate = self
                }

            case "SetTerminalTimeouts":
                if let terminalTimeoutsViewController = segue.destination
                    as? TerminalTimeoutsViewController,
                    let terminal = terminal,
                    let defaults = UserDefaults(suiteName: "com.acs.BLETest."
                        + terminal.name) {

                    // Load the settings.
                    let connectionTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefConnectionTimeout)
                    let powerTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefPowerTimeout)
                    let protocolTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefProtocolTimeout)
                    let apduTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefApduTimeout)
                    let controlTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefControlTimeout)

                    terminalTimeoutsViewController.connectionTimeout = connectionTimeout
                    terminalTimeoutsViewController.powerTimeout = powerTimeout
                    terminalTimeoutsViewController.protocolTimeout = protocolTimeout
                    terminalTimeoutsViewController.apduTimeout = apduTimeout
                    terminalTimeoutsViewController.controlTimeout = controlTimeout
                    terminalTimeoutsViewController.delegate = self
                }

            default:
                break
            }
        }
    }

    @IBAction func unwindToMain(segue: UIStoryboardSegue) {

        if let identifier = segue.identifier {
            switch identifier {

            case "ReturnTerminal":
                // Stop the scan.
                manager.stopScan()

                if let terminalListViewController = segue.source
                    as? TerminalListViewController,
                    let terminal = terminalListViewController.terminal,
                    let defaults = UserDefaults(suiteName: "com.acs.BLETest."
                        + terminal.name) {

                    // Store the selected card terminal.
                    self.terminal = terminal

                    // Show the name.
                    terminalLabel.text = terminal.name

                    // Load the settings.
                    let isDefaultKeyUsed = defaults.bool(
                        forKey: MainViewController.keyPrefUseDefaultKey)
                    let connectionTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefConnectionTimeout)
                    let powerTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefPowerTimeout)
                    let protocolTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefProtocolTimeout)
                    let apduTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefApduTimeout)
                    let controlTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefControlTimeout)

                    // Show the settings.
                    masterKeyLabel.text = isDefaultKeyUsed ?
                        "Default Key" : "Custom Key"
                    terminalTimeoutsLabel.text =
                        connectionTimeout == TerminalTimeouts.defaultTimeout
                        && powerTimeout == TerminalTimeouts.defaultTimeout
                        && protocolTimeout == TerminalTimeouts.defaultTimeout
                        && apduTimeout == TerminalTimeouts.defaultTimeout
                        && controlTimeout == TerminalTimeouts.defaultTimeout ?
                            "Default Timeout" : "Custom Timeout"
                    showCardStateLabel.text =
                        cardStateMonitor.isTerminalEnabled(terminal) ?
                            "Hide Card State" : "Show Card State"

                    // Update the table view.
                    tableView.reloadData()
                }

            case "CancelTerminal":
                // Stop the scan.
                manager.stopScan()

            default:
                break
            }
        }
    }

    /// Runs the script.
    ///
    /// - Parameters:
    ///   - card: the card
    ///   - filename: the filename
    ///   - send: the closure for sending command and receiving response
    func runScript(card: Card,
                   filename: String,
                   send: (Card, [UInt8]) throws -> [UInt8]) {

        // Open the log file.
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let logFilename = "Log-" + dateFormatter.string(from: currentDate)
            + ".txt"
        logger.openLogFile(name: logFilename)
        logger.logMsg("Running the script...")

        // Open the script file.
        logger.logMsg("Opening " + filename + "...")
        let hScriptFile = openFile(name: filename)
//        if (hScriptFile == nil) {
//
//            logger.logMsg("Error: Script file not found")
//            return
//        }

        do {

            var numCommands = 0
            while true {

                var commandLoaded = false
                var responseLoaded = false
                var command = [UInt8]()
                command = [0xFF, 0xB0, 0x00, 0x04, 0x10]
                // Read the first line.
                /*var line = readLine(hFile: hScriptFile!)
                while line.count > 0 {

                    // Skip the comment line.
                    if !line.contains(";") {

                        if !commandLoaded {

                            command = Hex.toByteArray(hexString: line)
                            if command.count > 0 {
                                commandLoaded = true
                            }

                        } else {

                            if checkLine(line) > 0 {
                                responseLoaded = true
                            }
                        }
                    }

                    if commandLoaded && responseLoaded {
                        break
                    }

                    // Read the next line.
                    line = readLine(hFile: hScriptFile!)
                }

                if !commandLoaded || !responseLoaded {
                    break
                }

                // Increment the number of loaded commands.
                numCommands += 1*/

                logger.logMsg("Command:")
                logger.logBuffer(command)

                // Send the command.
                let startTime = Date()
                let response = try send(card, command)
                let endTime = Date()
                let time = endTime.timeIntervalSince(startTime)

                logger.logMsg("Response:")
                logger.logBuffer(response)

                logger.logMsg("Bytes Sent    : %d", command.count)
                logger.logMsg("Bytes Received: %d", response.count)
                logger.logMsg("Transfer Time : %.2f ms", time * 1000.0)
                logger.logMsg("Transfer Rate : %.2f bytes/second",
                              Double(command.count + response.count) / time)

                logger.logMsg("Expected:")
//                logger.logHexString(line)

                // Compare the response.
//                if compareResponse(line: line, response: response) {
//
//                    logger.logMsg("Compare OK")
//
//                } else {
//
//                    logger.logMsg("Error: Unexpected response")
//                    break
//                }
            }

            if numCommands == 0 {
                logger.logMsg("Error: Cannot load the command")
            }

        } catch {

            logger.logMsg("Error: " + error.localizedDescription)
        }

        // Close the script file.
//        hScriptFile!.closeFile()

        // Close the log file.
        logger.closeLogFile()
    }

    /// Opens the file.
    ///
    /// - Parameter name: the filename
    /// - Returns: the file handle
    func openFile(name: String) -> FileHandle? {

        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                        .userDomainMask,
                                                        true)
        let documentsDirectory = paths[0]
        let filePath = NSString(string: documentsDirectory)
            .appendingPathComponent(name)

        return FileHandle(forReadingAtPath: filePath)
    }

    /// Reads the line from file.
    ///
    /// - Parameter hFile: the file handle
    /// - Returns: the line
    func readLine(hFile: FileHandle) -> String {

        var line = ""

        // Read the first byte.
        var buffer = hFile.readData(ofLength: 1)
        while buffer.count > 0 {

            // Append the byte to the line.
            if let byteString = String(data: buffer,
                                       encoding: String.Encoding.ascii) {
                line += byteString
                if byteString == "\n" {
                    break
                }
            }

            // Read the next byte.
            buffer = hFile.readData(ofLength: 1)
        }

        return line
    }

    /// Checks the line.
    ///
    /// - Parameter line: the line
    /// - Returns: the number of characters
    func checkLine(_ line: String) -> Int {

        var count = 0

        for c in line {
            if c >= Character("0") && c <= Character("9")
                || c >= Character("A") && c <= Character("F")
                || c >= Character("a") && c <= Character("f")
                || c == Character("X")
                || c == Character("x") {
                count += 1
            }
        }

        return count
    }

    /// Compares the response with line.
    ///
    /// - Parameters:
    ///   - line: the line
    ///   - response: the response
    func compareResponse(line: String, response: [UInt8]) -> Bool {

        var ret = true
        var length = 0
        var first = true
        var num = 0
        var num2 = 0
        var i = 0

        let digit0: Unicode.Scalar = "0"
        let digit9: Unicode.Scalar = "9"
        let letterA: Unicode.Scalar = "A"
        let letterF: Unicode.Scalar = "F"
        let letterX: Unicode.Scalar = "X"
        let lettera: Unicode.Scalar = "a"
        let letterf: Unicode.Scalar = "f"
        let letterx: Unicode.Scalar = "x"

        for c in line.unicodeScalars {

            if c >= digit0 && c <= digit9 {
                num = Int(c.value - digit0.value)
            } else if c >= letterA && c <= letterF {
                num = Int(c.value - letterA.value + 10)
            } else if c >= lettera && c <= letterf {
                num = Int(c.value - lettera.value + 10)
            } else {
                num = -1
            }

            if num >= 0 || c == letterX || c == letterx {

                // Increment the string length.
                length += 1

                if i >= response.count {

                    ret = false
                    break
                }

                if first {

                    num2 = Int(response[i]) >> 4 & 0x0F

                } else {

                    num2 = Int(response[i]) & 0x0F
                    i += 1
                }

                first = !first

                if c == letterX || c == letterx {
                    num = num2
                }

                // Compare two numbers.
                if num2 != num {

                    ret = false
                    break
                }
            }
        }

        // Return false if the length is not matched.
        if length != 2 * response.count {
            ret = false
        }

        return ret
    }

    /// Returns the description from the battery status.
    ///
    /// - Since: 0.4
    /// - Parameter batteryStatus: the battery status
    /// - Returns: the description
    func toBatteryStatusString(
        batteryStatus: BluetoothTerminalManager.BatteryStatus) -> String {

        var string: String

        switch batteryStatus {

        case .notSupported:
            string = "Not supported"

        case .none:
            string = "No battery"

        case .low:
            string = "Low"

        case .full:
            string = "Full"

        case .usbPlugged:
            string = "USB plugged"
        }

        return string
    }

    // MARK: - Table View

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: false)

        if let cell = tableView.cellForRow(at: indexPath),
            let reuseIdentifier = cell.reuseIdentifier {
            switch reuseIdentifier {

            case "GetBatteryStatus":
                // Check the selected card terminal.
                let terminal: CardTerminal! = self.terminal
                if terminal == nil {

                    logger.logMsg("Error: Card terminal not selected")
                    break
                }

                cell.isUserInteractionEnabled = false
                DispatchQueue.global().async {

                    do {

                        self.logger.logMsg("Getting the battery status ("
                            + terminal.name + ")...")
                        let batteryStatus = try self.manager.batteryStatus(
                            terminal: terminal,
                            timeout: 10000)
                        self.logger.logMsg("Battery Status: "
                            + self.toBatteryStatusString(
                                batteryStatus: batteryStatus))

                    } catch {

                        self.logger.logMsg("Error: "
                            + error.localizedDescription)
                    }

                    DispatchQueue.main.async {
                        cell.isUserInteractionEnabled = true
                    }
                }

            case "GetBatteryLevel":
                // Check the selected card terminal.
                let terminal: CardTerminal! = self.terminal
                if terminal == nil {

                    logger.logMsg("Error: Card terminal not selected")
                    break
                }

                cell.isUserInteractionEnabled = false
                DispatchQueue.global().async {

                    do {

                        self.logger.logMsg("Getting the battery level ("
                            + terminal.name + ")...")
                        let batteryLevel = try self.manager.batteryLevel(
                            terminal: terminal,
                            timeout: 10000)
                        if batteryLevel < 0 {
                            self.logger.logMsg("Battery Level: Not supported")
                        } else {
                            self.logger.logMsg("Battery Level: %d%%",
                                               batteryLevel)
                        }

                    } catch {

                        self.logger.logMsg("Error: "
                            + error.localizedDescription)
                    }

                    DispatchQueue.main.async {
                        cell.isUserInteractionEnabled = true
                    }
                }

            case "GetDeviceInfo":
                // Check the selected card terminal.
                let terminal: CardTerminal! = self.terminal
                if terminal == nil {

                    logger.logMsg("Error: Card terminal not selected")
                    break
                }

                let texts = [

                    "System ID        : ",
                    "Model Number     : ",
                    "Serial Number    : ",
                    "Firmware Revision: ",
                    "Hardware Revision: ",
                    "Software Revision: ",
                    "Manufacturer Name: "
                ]

                let types = [

                    BluetoothTerminalManager.DeviceInfoType.systemId,
                    BluetoothTerminalManager.DeviceInfoType.modelNumberString,
                    BluetoothTerminalManager.DeviceInfoType.serialNumberString,
                    BluetoothTerminalManager.DeviceInfoType.firmwareRevisionString,
                    BluetoothTerminalManager.DeviceInfoType.hardwareRevisionString,
                    BluetoothTerminalManager.DeviceInfoType.softwareRevisionString,
                    BluetoothTerminalManager.DeviceInfoType.manufacturerNameString,
                ]

                cell.isUserInteractionEnabled = false
                DispatchQueue.global().async {

                    do {

                        self.logger.logMsg("Getting the device information ("
                            + terminal.name + ")...")
                        for i in 0..<texts.count {

                            if let deviceInfo = try self.manager.deviceInfo(
                                terminal: terminal,
                                type: types[i],
                                timeout: 10000) {
                                self.logger.logMsg(texts[i] + deviceInfo)
                            } else {
                                self.logger.logMsg(texts[i] + "Not supported")
                            }
                        }

                    } catch {

                        self.logger.logMsg("Error: "
                            + error.localizedDescription)
                    }

                    DispatchQueue.main.async {
                        cell.isUserInteractionEnabled = true
                    }
                }

            case "ShowCardState":
                // Check the selected card terminal.
                let terminal: CardTerminal! = self.terminal
                if terminal == nil {

                    logger.logMsg("Error: Card terminal not selected")
                    break
                }

                // Show or hide the card state.
                if cardStateMonitor.isTerminalEnabled(terminal) {

                    cardStateMonitor.removeTerminal(terminal)
                    showCardStateLabel.text = "Show Card State"

                } else {

                    cardStateMonitor.addTerminal(terminal)
                    showCardStateLabel.text = "Hide Card State"
                }

                // Update the table view.
                tableView.reloadData()
                break;

            case "Transmit":
                // Check the selected card terminal.
                let terminal: CardTerminal! = self.terminal
                if terminal == nil {

                    logger.logMsg("Error: Card terminal not selected")
                    break
                }

                // Check the selected filename.
                let filename: String! = self.filename
//                if filename == nil {
//
//                    logger.logMsg("Error: File not selected")
//                    break
//                }

                // Check the selected protocol.
                var protocolString = ""
                if protocols[0] {
                    if protocols[1] {
                        protocolString = "*"
                    } else {
                        protocolString = "T=0"
                    }
                } else {
                    if protocols[1] {
                        protocolString = "T=1"
                    } else {
                        logger.logMsg("Error: Protocol not selected")
                        break
                    }
                }

                // Clear the log.
                logger.clear()

                cell.isUserInteractionEnabled = false
                DispatchQueue.global().async {

                    do {

                        // Connect to the card.
                        self.logger.logMsg("Connecting to the card ("
                            + terminal.name + ", " + protocolString + ")...")
                        let card = try terminal.connect(
                            protocolString: protocolString)

                        // Get the ATR string.
                        self.logger.logMsg("ATR:")
                        self.logger.logBuffer(card.atr.bytes)

                        // Get the active protocol.
                        self.logger.logMsg("Active Protocol: "
                            + card.activeProtocol)
                        self.readCardType(atr: card.atr.bytes,card: card)
                        
                        // Run the script.
//                        self.runScript(card: card, filename: "") {
//
//                            let channel = try $0.basicChannel()
//                            let commandAPDU = try CommandAPDU(apdu: $1)
//                            let responseAPDU = try channel.transmit(
//                                apdu: commandAPDU)
//
//                            return responseAPDU.bytes
//                        }

                        // Disconnect from the card.
//                        self.logger.logMsg("Disconnecting the card ("
//                            + terminal.name + ")...")
//                        try card.disconnect(reset: false)

                    } catch {

                        self.logger.logMsg("Error: "
                            + error.localizedDescription)
                    }

                    DispatchQueue.main.async {
                        cell.isUserInteractionEnabled = true
                    }
                }

            case "Control":
                // Check the selected card terminal.
                let terminal: CardTerminal! = self.terminal
                if terminal == nil {

                    logger.logMsg("Error: Card terminal not selected")
                    break
                }

                // Check the selected filename.
                let filename: String! = self.filename
//                if filename == nil {
//
//                    logger.logMsg("Error: File not selected")
//                    break
//                }

                // Check the control code.
                var controlCode = 0
                if let numberString = controlCodeTextField.text,
                    let number = Int(numberString) {

                    controlCode = number

                } else {

                    logger.logMsg("Error: Invalid control code")
                    break
                }

                // Clear the log.
                logger.clear()

                cell.isUserInteractionEnabled = false
                DispatchQueue.global().async {

                    do {

                        // Connect to the card.
                        self.logger.logMsg("Connecting to the card ("
                            + terminal.name + ", direct)...")
                        let card = try terminal.connect(
                            protocolString: "direct")

                        // Run the script.
                        self.runScript(card: card, filename: filename) {
                            return try $0.transmitControlCommand(
                                controlCode: controlCode,
                                command: $1)
                        }

                        // Disconnect from the card.
                        self.logger.logMsg("Disconnecting the card ("
                            + terminal.name + ")...")
                        try card.disconnect(reset: false)

                    } catch {

                        self.logger.logMsg("Error: "
                            + error.localizedDescription)
                    }

                    DispatchQueue.main.async {
                        cell.isUserInteractionEnabled = true
                    }
                }

            case "Disconnect":
                // Check the selected card terminal.
                let terminal: CardTerminal! = self.terminal
                if terminal == nil {

                    logger.logMsg("Error: Card terminal not selected")
                    break
                }

                // Remove the terminal from card state monitor.
                cardStateMonitor.removeTerminal(terminal)
                showCardStateLabel.text = "Show Card State"
                tableView.reloadData()

                cell.isUserInteractionEnabled = false
                DispatchQueue.global().async {

                    do {

                        // Disconnect from the terminal.
                        self.logger.logMsg("Disconnecting " + terminal.name
                            + "...")
                        try self.manager.disconnect(terminal: terminal)

                    } catch {

                        self.logger.logMsg("Error: "
                            + error.localizedDescription)
                    }

                    DispatchQueue.main.async {
                        cell.isUserInteractionEnabled = true
                    }
                }

            default:
                break
            }
        }
    }
    
    func readCardType(atr:[UInt8],card: SmartCardIO.Card) {
        cardName = "Unknown"
        let byteArray: [Int8] = [-96, 0, 0, 3, 6]
        let bArr: [UInt8] = byteArray.map { UInt8(bitPattern: $0) }
        if atr.count < 4 {
            print("Invalid card detected")
        } else if atr[4] == UInt8(bitPattern: -128) && atr[5] == 79 {
            if Array(atr[7..<12]) == bArr {
                let copyOfRange = Array(atr[13..<15])
                let b = copyOfRange[1]
                
                if b != 59 {
                    switch b {
                    case 1, 2:
                        cardName = "Mifare Classic"
                    default:
                        self.getOthersCardType(Int(copyOfRange[1]))
                        print("Invalid card detected")
                    }
                } else {
                    cardName = "Felica"
                }
            } else {
                print("Invalid card detected")
            }
        } else if atr[4] == 16 {
            cardName = "Memory Card"
            print("Invalid card detected")
        } else if atr[4] == 0 {
//            getCardVersion()
        } else { }
        
        print("Card Name :::::::: ",cardName)
        self.getTagUDID(card: card)
    }

    
    func getTagUDID(card: SmartCardIO.Card){
        do {
            let basicChannel = try card.basicChannel()
            
            let command: [UInt8] = [0xFF, 0xCA, 0x00, 0x00, 0x00]//Hex.toByteArray(hexString: readCommandHex1)
            let response = try basicChannel.transmit(apdu: CommandAPDU(apdu: command))
            print("UDID COmmand response data: \(response.data)")
            print("UDID COmmand response bytes: \(response.bytes)")
            print("UDID COmmand response sw: \(response.sw)")
            print("UDID COmmand response sw1: \(response.sw1)")
            print("UDID COmmand response sw2: \(response.sw2)")
            print("UDID COmmand Response status: \(String(format: "0x%04X", response.sw))")
            print("UDID COmmand toHexString",self.toHexString(response.data))
            print("UDID COmmand  toHexString ====>",self.byteArrayToString(response.data, length: response.data.count))
            
            
            var str = ""
            
            for (index,byte) in response.data.enumerated() {
                let hexString = String(format: "%02X", byte)
                if index == (response.data.count - 1){
                    str += hexString
                }
                else{
                    str += hexString + ":"
                }
            }
            print("str",str)
        }
        catch {
            print("Error: \(error)")
        }
    }
    
    private func getOthersCardType(_ i: Int) {
        switch i {
            case 3:
                cardName = "Mifare Ultralight"
            case 4:
                cardName = "SLE55R_XXXX"
            case 6:
                cardName = "SR176"
            case 7:
                cardName = "SRI X4K"
            case 8:
                cardName = "AT88RF020"
            case 9:
                cardName = "AT88SC0204CRF"
            case 10:
                cardName = "AT88SC0808CRF"
            case 11:
                cardName = "AT88SC1616CRF"
            case 12:
                cardName = "AT88SC3216CRF"
            case 13:
                cardName = "AT88SC6416CRF"
            case 14:
                cardName = "SRF55V10P"
            case 15:
                cardName = "SRF55V02P"
            case 16:
                cardName = "SRF55V10S"
            case 17:
                cardName = "SRF55V02S"
            case 18:
                cardName = "TAG IT"
            case 19:
                cardName = "LR1512"
            case 20:
                cardName = "ICODESLI"
            case 21:
                cardName = "TEMPSENS"
            case 22:
                cardName = "I.CODE1"
            case 23:
                cardName = "PicoPass 2K"
            case 24:
                cardName = "PicoPass 2KS"
            case 25:
                cardName = "PicoPass 16K"
            case 26:
                cardName = "PicoPass 16Ks"
            case 27:
                cardName = "PicoPass 16K(8x2)"
            case 28:
                cardName = "PicoPass 16Ks(8x2)"
            case 29:
                cardName = "PicoPass 32KS(16+16)"
            case 30:
                cardName = "PicoPass 32KS(16+8x2)"
            case 31:
                cardName = "PicoPass 32KS(8x2+16)"
            case 32:
                cardName = "PicoPass 32KS(8x2+8x2)"
            case 33:
                cardName = "LRI64"
            case 34:
                cardName = "I.CODE UID"
            case 35:
                cardName = "I.CODE EPC"
            case 36:
                cardName = "LRI12"
            case 37:
                cardName = "LRI128"
            case 38:
                cardName = "Mifare Mini"
            case 39:
                cardName = "my-d move (SLE 66R01P)"
            case 40:
                cardName = "my-d NFC (SLE 66RxxP)"
            case 41:
                cardName = "my-d proximity 2 (SLE 66RxxS)"
            case 42:
                cardName = "my-d proximity enhanced (SLE 55RxxE)"
            case 43:
                cardName = "my-d light (SRF 55V01P))"
            case 44:
                cardName = "PJM Stack Tag (SRF 66V10ST)"
            case 45:
                cardName = "PJM Item Tag (SRF 66V10IT)"
            case 46:
                cardName = "PJM Light (SRF 66V01ST)"
            case 47:
                cardName = "Jewel Tag"
            case 48:
                cardName = "Topaz NFC Tag"
            case 49:
                cardName = "AT88SC0104CRF"
            case 50:
                cardName = "AT88SC0404CRF"
            case 51:
                cardName = "AT88RF01C"
            case 52:
                cardName = "AT88RF04C"
            case 53:
                cardName = "i-Code SL2"
            case 54:
                cardName = "Mifare Plus SL1_2K"
            case 55:
                cardName = "Mifare Plus SL1_4K"
            case 56:
                cardName = "Mifare Plus SL2_2K"
            case 57:
                cardName = "Mifare Plus SL2_4K"
            case 58:
                cardName = "Mifare Ultralight C"
            case 59:
                cardName = "FeliCa"
            case 60:
                cardName = "Melexis Sensor Tag (MLX90129)"
            case 61:
                cardName = "Mifare Ultralight EV1"
            default:
                break
        }
    }

    
    
    func readCardValue(card: SmartCardIO.Card) {
//        self.readWriteAuthCommand(card: card)
        self.readNFCTagCommand(card: card)
    }
    
    func readNFCTagCommand(card: SmartCardIO.Card){
        do {
            let basicChannel = try card.basicChannel()
            
            
            // Define the starting page and the number of bytes to read
               let startingPage: UInt8 = 0x07
               let bytesToRead: UInt8 = 0x20//0x10
               
               // Initialize an array to store the concatenated data
               var responseData = [UInt8]()
               
               // Loop to read multiple pages
            for page in startingPage...(startingPage + bytesToRead - 1) {
                // Define the APDU command to read 4 bytes from the current page
                let readCommand: [UInt8] = [0xFF, 0xB0, 0x00, page, 0x04]
//                self.executeCommand(command: readCommand, channel: basicChannel, stringPrint: "Name readCommand")
                
                // Send the APDU command to the card
                        let response = try basicChannel.transmit(apdu: CommandAPDU(apdu: readCommand))
                        
                        // Check the response status
                        if response.sw1 == 0x90 && response.sw2 == 0x00 {
                            // Successful response
                            let pageData = response.data
                            responseData += pageData
                        } else {
                            // Error response
                            print("Error response: \(response.sw1), \(response.sw2)")
                            break // Exit the loop on error
                        }
                
            }
//            print("responseData",responseData)
            print(" toHexString",self.toHexString(responseData))
            print("\toHexString ====>",self.byteArrayToString(responseData, length: responseData.count))
            
//            let readNameCommandHex = "FF B0 00 07 10"//[0xFF, 0xB0, 0x00, 0x04, 0x10]//
//            let readNameCommand: [UInt8] = Hex.toByteArray(hexString: readNameCommandHex)
//            self.executeCommand(command: readNameCommand, channel: basicChannel, stringPrint: "Name readCommand")
            
        }
        catch {
            print("Error: \(error)")
        }
    }
    
    func readWriteAuthCommand(card: SmartCardIO.Card){
        do {
            let basicChannel = try card.basicChannel()
            
            let loadAuthCommandHex = "FF 82 00 00 06 FF FF FF FF FF FF"
            let loadAuthCommand: [UInt8] = Hex.toByteArray(hexString: loadAuthCommandHex)
            self.executeCommand(command: loadAuthCommand, channel: basicChannel, stringPrint: "loadAuthCommand")
            
            
            let authCommandHex = "FF 86 00 00 05 01 00 04 60 00"
            let authCommand: [UInt8] = Hex.toByteArray(hexString: authCommandHex)
            self.executeCommand(command: authCommand, channel: basicChannel, stringPrint: "authCommand")
            
            
            
            let readNameCommandHex = "FF B0 00 05 20"
            let readNameCommand: [UInt8] = Hex.toByteArray(hexString: readNameCommandHex)
            self.executeCommand(command: readNameCommand, channel: basicChannel, stringPrint: "Name readCommand")
            
            let authCommandHex2 = "FF 86 00 00 05 01 00 08 60 00"
            let authCommand2: [UInt8] = Hex.toByteArray(hexString: authCommandHex2)
            self.executeCommand(command: authCommand2, channel: basicChannel, stringPrint: "authCommand")
            
            
            let readCommandHex = "FF B0 00 08 10"
            let readCommand: [UInt8] = Hex.toByteArray(hexString: readCommandHex)
            self.executeCommand(command: readCommand, channel: basicChannel, stringPrint: "Organization readCommand")
            
            let readCommandHex1 = "FF B0 00 09 10"
            let readCommand1: [UInt8] = Hex.toByteArray(hexString: readCommandHex1)
            self.executeCommand(command: readCommand1, channel: basicChannel, stringPrint: "Position readCommand")
            
        }
        catch {
            print("Error: \(error)")
        }
    }
    
    func executeCommand(command: [UInt8],channel: CardChannel,stringPrint:String){
        // Use the basic logical channel to transmit the write command
        do {
            let response = try channel.transmit(apdu: CommandAPDU(apdu: command))
            print("\(stringPrint) response data: \(response.data)")
            print("\(stringPrint) response bytes: \(response.bytes)")
            print("\(stringPrint) response sw: \(response.sw)")
            print("\(stringPrint) response sw1: \(response.sw1)")
            print("\(stringPrint) response sw2: \(response.sw2)")
            print("\(stringPrint) Response status: \(String(format: "0x%04X", response.sw))")
            print("\(stringPrint) toHexString",self.toHexString(response.bytes))
            print("\(stringPrint)  toHexString ====>",self.byteArrayToString(response.bytes, length: response.bytes.count))
        }catch {
            print("Error: \(error)")
        }
    }
    func byteArrayToString(_ byteArray: [UInt8], length: Int) -> String {
        var str = ""
        var i2 = 0
        
        while i2 < length && byteArray[i2] != 0 {
            let byteValue = byteArray[i2]
            // Check if the byte value is within the printable ASCII range
            if (0x20...0x7E).contains(byteValue) {
                str.append(Character(UnicodeScalar(byteValue)))
            }
            i2 += 1
        }
        
        return removeLanguageIndicator(str)//str
    }
    func removeLanguageIndicator(_ inputString: String) -> String {
        let regex = try! NSRegularExpression(pattern: "^[a-z]+[A-Z]")
        let range = NSRange(inputString.startIndex..<inputString.endIndex, in: inputString)

        if let match = regex.firstMatch(in: inputString, options: [], range: range) {
//            let startIndex = inputString.index(inputString.startIndex, offsetBy: match.range.upperBound)
//            return String(inputString[startIndex...])
            if inputString.count >= 2 {
                    let startIndex = inputString.index(inputString.startIndex, offsetBy: 2)
                    return String(inputString[startIndex...])
                } else {
                    return ""
                }
        }
        
        return inputString
    }
    func toHexString(_ byteArray: [UInt8]?) -> String {
        var str = ""
        
        if let byteArray = byteArray {
            for byte in byteArray {
                let hexString = String(format: "%02X", byte)
                str += hexString + " "
            }
        }
        
        return str
    }
    func stringToByteArray(_ str: String, _ length: Int) -> [UInt8] {
        var bArr = [UInt8](repeating: 0, count: length)
        
        for (i, char) in str.prefix(length).enumerated() {
            bArr[i] = UInt8(char.asciiValue ?? 0)
        }
        
        return bArr
    }
    

}

// MARK: - UITextFieldDelegate
extension MainViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        if textField == controlCodeTextField {
            textField.resignFirstResponder()
        }

        return true
    }
}

// MARK: - BluetoothTerminalManagerDelegate
extension MainViewController: BluetoothTerminalManagerDelegate {

    func bluetoothTerminalManagerDidUpdateState(
        _ manager: BluetoothTerminalManager) {

        var message = ""

        switch manager.centralManager.state {

        case .unknown, .resetting:
            message = "The update is being started. Please wait until Bluetooth is ready."

        case .unsupported:
            message = "This device does not support Bluetooth low energy."

        case .unauthorized:
            message = "This app is not authorized to use Bluetooth low energy."

        case .poweredOff:
            if !firstRun {
                message = "You must turn on Bluetooth in Settings in order to use the reader."
            }

        default:
            break
        }

        if !message.isEmpty {

            // Show the alert.
            let alert = UIAlertController(title: "Bluetooth",
                                          message: message,
                                          preferredStyle: .alert)
            let defaultAction = UIAlertAction(title: "OK", style: .default)
            alert.addAction(defaultAction)
            DispatchQueue.main.async {
                self.present(alert, animated: true)
            }
        }

        firstRun = false
    }

    func bluetoothTerminalManager(_ manager: BluetoothTerminalManager,
                                  didDiscover terminal: CardTerminal) {

        // Show the terminal.
        if let terminalListViewController = terminalListViewController {
            if !terminalListViewController.terminals.contains(
                where: { $0 === terminal }) {

                terminalListViewController.terminals.append(terminal)
                DispatchQueue.main.async {
                    terminalListViewController.tableView.reloadData()
                }

                if let defaults = UserDefaults(suiteName: "com.acs.BLETest."
                    + terminal.name) {

                    // Set default values.
                    defaults.register(defaults: [
                        MainViewController.keyPrefUseDefaultKey: true,
                        MainViewController.keyPrefNewKey: "",
                        MainViewController.keyPrefConnectionTimeout:
                            TerminalTimeouts.defaultTimeout,
                        MainViewController.keyPrefPowerTimeout:
                            TerminalTimeouts.defaultTimeout,
                        MainViewController.keyPrefProtocolTimeout:
                            TerminalTimeouts.defaultTimeout,
                        MainViewController.keyPrefApduTimeout:
                            TerminalTimeouts.defaultTimeout,
                        MainViewController.keyPrefControlTimeout:
                            TerminalTimeouts.defaultTimeout])

                    // Load the settings.
                    let isDefaultKeyUsed = defaults.bool(
                        forKey: MainViewController.keyPrefUseDefaultKey)
                    let newKey = defaults.string(
                        forKey: MainViewController.keyPrefNewKey) ?? ""
                    let connectionTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefConnectionTimeout)
                    let powerTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefPowerTimeout)
                    let protocolTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefProtocolTimeout)
                    let apduTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefApduTimeout)
                    let controlTimeout = defaults.integer(
                        forKey: MainViewController.keyPrefControlTimeout)

                    // Set the master key.
                    if !isDefaultKeyUsed {

                        logger.logMsg("Setting the master key (" + terminal.name
                            + ")...")
                        do {
                            try manager.setMasterKey(
                                terminal: terminal,
                                masterKey: Hex.toByteArray(hexString: newKey))
                        } catch {
                            logger.logMsg("Error: "
                                + error.localizedDescription)
                        }
                    }

                    // Set the terminal timeouts.
                    logger.logMsg("Setting the terminal timeouts ("
                        + terminal.name + ")...")
                    do {

                        let timeouts = try manager.timeouts(terminal: terminal)
                        timeouts.connectionTimeout = connectionTimeout
                        timeouts.powerTimeout = powerTimeout
                        timeouts.protocolTimeout = protocolTimeout
                        timeouts.apduTimeout = apduTimeout
                        timeouts.controlTimeout = controlTimeout

                    } catch {

                        logger.logMsg("Error: " + error.localizedDescription)
                    }
                }
            }
        }
    }
}

// MARK: - TerminalListViewControllerDelegate
extension MainViewController: TerminalListViewControllerDelegate {

    func terminalListViewController(
        _ terminalListViewController: TerminalListViewController,
        didSelectTerminal terminal: CardTerminal) {

        // Store the selected card terminal.
        self.terminal = terminal

        // Show the name.
        terminalLabel.text = terminal.name

        if let defaults = UserDefaults(suiteName: "com.acs.BLETest."
            + terminal.name) {

            // Load the settings.
            let isDefaultKeyUsed = defaults.bool(
                forKey: MainViewController.keyPrefUseDefaultKey)
            let connectionTimeout = defaults.integer(
                forKey: MainViewController.keyPrefConnectionTimeout)
            let powerTimeout = defaults.integer(
                forKey: MainViewController.keyPrefPowerTimeout)
            let protocolTimeout = defaults.integer(
                forKey: MainViewController.keyPrefProtocolTimeout)
            let apduTimeout = defaults.integer(
                forKey: MainViewController.keyPrefApduTimeout)
            let controlTimeout = defaults.integer(
                forKey: MainViewController.keyPrefControlTimeout)

            // Show the settings.
            masterKeyLabel.text = isDefaultKeyUsed ?
                "Default Key" : "Custom Key"
            terminalTimeoutsLabel.text =
                connectionTimeout == TerminalTimeouts.defaultTimeout
                && powerTimeout == TerminalTimeouts.defaultTimeout
                && protocolTimeout == TerminalTimeouts.defaultTimeout
                && apduTimeout == TerminalTimeouts.defaultTimeout
                && controlTimeout == TerminalTimeouts.defaultTimeout ?
                    "Default Timeout" : "Custom Timeout"
            showCardStateLabel.text =
                cardStateMonitor.isTerminalEnabled(terminal) ?
                    "Hide Card State" : "Show Card State"
        }

        // Update the table view.
        tableView.reloadData()
    }
}

// MARK: - ProtocolViewControllerDelegate
extension MainViewController: ProtocolViewControllerDelegate {

    func protocolViewController(
        _ protocolViewController: ProtocolViewController,
        didSelectProtocols protocols: [Bool]) {

        var protocolText = ""

        if protocols[0] {
            if protocols[1] {
                protocolText = "T=0 or T=1"
            } else {
                protocolText = "T=0"
            }
        } else {
            if protocols[1] {
                protocolText = "T=1"
            } else {
                protocolText = "Unknown"
            }
        }

        // Store the selected protocol.
        self.protocols = protocols

        // Update the protocol text.
        protocolLabel.text = protocolText
        tableView.reloadData()
    }
}

// MARK: - FileListViewControllerDelegate
extension MainViewController: FileListViewControllerDelegate {

    func fileListViewController(
        _ fileListViewController: FileListViewController,
        didSelectFile filename: String) {

        // Store the selected filename.
        self.filename = filename

        // Update the filename.
        scriptFileLabel.text = filename
        tableView.reloadData()
    }
}

// MARK: - MasterKeyViewControllerDelegate
extension MainViewController: MasterKeyViewControllerDelegate {

    func masterKeyViewController(
        _ masterKeyViewController: MasterKeyViewController,
        didUpdateSettings isDefaultKeyUsed: Bool,
        newKey: String) {

        // Show the settings.
        masterKeyLabel.text = isDefaultKeyUsed ? "Default Key" : "Custom Key"

        if let terminal = terminal,
            let defaults = UserDefaults(suiteName: "com.acs.BLETest."
                + terminal.name) {

            // Save the settings.
            defaults.set(isDefaultKeyUsed,
                         forKey: MainViewController.keyPrefUseDefaultKey)
            defaults.set(newKey, forKey: MainViewController.keyPrefNewKey)

            // Set the master key.
            logger.logMsg("Setting the master key (" + terminal.name + ")...")
            do {
                try manager.setMasterKey(
                    terminal: terminal,
                    masterKey: isDefaultKeyUsed ?
                        nil : Hex.toByteArray(hexString: newKey))
            } catch {
                logger.logMsg("Error: " + error.localizedDescription)
            }
        }
    }
}

// MARK: - TerminalTimeoutsViewControllerDelegate
extension MainViewController: TerminalTimeoutsViewControllerDelegate {

    func terminalTimeoutsViewController(
        _ terminalTimeoutsViewController: TerminalTimeoutsViewController,
        didUpdateSettings connectionTimeout: Int,
        powerTimeout: Int,
        protocolTimeout: Int,
        apduTimeout: Int,
        controlTimeout: Int) {

        // Show the settings.
        terminalTimeoutsLabel.text =
            connectionTimeout == TerminalTimeouts.defaultTimeout
            && powerTimeout == TerminalTimeouts.defaultTimeout
            && protocolTimeout == TerminalTimeouts.defaultTimeout
            && apduTimeout == TerminalTimeouts.defaultTimeout
            && controlTimeout == TerminalTimeouts.defaultTimeout ?
                "Default Timeout" : "Custom Timeout"

        if let terminal = terminal,
            let defaults = UserDefaults(suiteName: "com.acs.BLETest."
                + terminal.name) {

            // Save the settings.
            defaults.set(connectionTimeout,
                         forKey: MainViewController.keyPrefConnectionTimeout)
            defaults.set(powerTimeout,
                         forKey: MainViewController.keyPrefPowerTimeout)
            defaults.set(protocolTimeout,
                         forKey: MainViewController.keyPrefProtocolTimeout)
            defaults.set(apduTimeout,
                         forKey: MainViewController.keyPrefApduTimeout)
            defaults.set(controlTimeout,
                         forKey: MainViewController.keyPrefControlTimeout)

            // Set the terminal timeouts.
            logger.logMsg("Setting the terminal timeouts ("
                + terminal.name + ")...")
            do {

                let timeouts = try manager.timeouts(terminal: terminal)
                timeouts.connectionTimeout = connectionTimeout
                timeouts.powerTimeout = powerTimeout
                timeouts.protocolTimeout = protocolTimeout
                timeouts.apduTimeout = apduTimeout
                timeouts.controlTimeout = controlTimeout

            } catch {

                logger.logMsg("Error: " + error.localizedDescription)
            }
        }
    }
}

// MARK: - CardStateMonitorDelegate
extension MainViewController: CardStateMonitorDelegate {

    func cardStateMonitor(_ monitor: CardStateMonitor,
                          didChangeState terminal: CardTerminal,
                          prevState: CardStateMonitor.CardState,
                          currState: CardStateMonitor.CardState) {
        if prevState.rawValue > CardStateMonitor.CardState.absent.rawValue
            && currState.rawValue <= CardStateMonitor.CardState.absent.rawValue {
            logger.logMsg(terminal.name + ": removed")
        } else if prevState.rawValue <= CardStateMonitor.CardState.absent.rawValue
            && currState.rawValue > CardStateMonitor.CardState.absent.rawValue {
            logger.logMsg(terminal.name + ": inserted")
        }
    }
}

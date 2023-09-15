//
// Copyright (C) 2020 Advanced Card Systems Ltd. All rights reserved.
//
// This software is the confidential and proprietary information of Advanced
// Card Systems Ltd. ("Confidential Information").  You shall not disclose such
// Confidential Information and shall use it only in accordance with the terms
// of the license agreement you entered into with ACS.
//

import Foundation
import SmartCardIO

/// The `CardStateMonitor` class is a singleton that monitors the card state of
/// the card terminal.
///
/// - Author:  Godfrey Chung
/// - Version: 1.0
/// - Date:    19 Feb 2020
/// - Since:   0.5.2
final class CardStateMonitor {

    /// The card state
    enum CardState: Int {

        /// The card state is unknown.
        case unknown

        /// The card state is absent.
        case absent

        /// The card state is present.
        case present
    }

    /// Returns the shared instance of `CardStateMonitor`.
    static let shared = CardStateMonitor()

    /// The delegate object you want to receive card state monitor events.
    var delegate: CardStateMonitorDelegate?

    private var terminals = [String: CardTerminal]()
    private var threads = [String: Thread]()

    /// Creates an instance of `CardStateMonitor`.
    private init() {
    }

    /// Returns `true` if the terminal is enabled.
    ///
    /// - Parameter terminal: the terminal
    /// - Returns: `true` if the terminal is enabled
    func isTerminalEnabled(_ terminal: CardTerminal) -> Bool {
        return terminals[terminal.name] != nil
    }

    /// Adds the terminal to the monitor.
    ///
    /// - Parameter terminal: the terminal
    func addTerminal(_ terminal: CardTerminal) {
        if !isTerminalEnabled(terminal) {

            // Create a thread for card detection.
            let thread = Thread(target: self,
                                selector:#selector(detectCard(param:)),
                                object: terminal)

            // Store the thread.
            threads[terminal.name] = thread

            // Store the terminal.
            terminals[terminal.name] = terminal

            // Start the card detection.
            thread.start()
        }
    }

    /// Removes the terminal from the monitor.
    ///
    /// - Parameter terminal: the terminal
    func removeTerminal(_ terminal: CardTerminal) {
        if isTerminalEnabled(terminal) {

            // Terminate the thread.
            if let thread = threads[terminal.name] {

                thread.cancel()
                threads[terminal.name] = nil
            }

            // Remove the terminal.
            terminals[terminal.name] = nil
        }
    }

    @objc private func detectCard(param: Any?) {

        let terminal = param as! CardTerminal

        #if DEBUG
        print("\(#function) Enter: \(terminal.name)")
        #endif

        var prevState = CardState.unknown
        while !Thread.current.isCancelled {

            // Get the current state.
            var currState: CardState
            do {
                currState = try terminal.isCardPresent() ? .present : .absent
            } catch {
                currState = .unknown
            }

            // Break if the thread is cancelled.
            if Thread.current.isCancelled {
                break
            }

            // Report the current state if the state is changed.
            if currState != prevState {
                delegate?.cardStateMonitor(self,
                                           didChangeState: terminal,
                                           prevState: prevState,
                                           currState: currState)
            }

            // Update the previous state.
            prevState = currState

            // Wait for the change.
            do {
                if currState == .absent {
                    _ = try terminal.waitForCardPresent(timeout: 1000)
                } else if currState == .present {
                    _ = try terminal.waitForCardAbsent(timeout: 1000)
                } else {
                    Thread.sleep(forTimeInterval: 0.5)  // 500 ms
                }
            } catch {
                print("\(#function) Error: \(error.localizedDescription)")
            }
        }

        #if DEBUG
        print("\(#function) Exit: \(terminal.name)")
        #endif
    }
}

/// The `CardStateMonitorDelegate` protocol defines the methods that a delegate
/// of a `CardStateMonitor` object must adopt.
protocol CardStateMonitorDelegate {

    /// Invoked when the card is inserted or removed.
    ///
    /// - Parameters:
    ///   - monitor: the card state monitor
    ///   - terminal: the card terminal
    ///   - prevState: the previous state
    ///   - currState: the current state
    func cardStateMonitor(_ monitor: CardStateMonitor,
                          didChangeState terminal: CardTerminal,
                          prevState: CardStateMonitor.CardState,
                          currState: CardStateMonitor.CardState)
}

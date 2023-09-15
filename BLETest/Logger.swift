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

/// The `Logger` class logs the message to text view.
///
/// - Author:  Godfrey Chung
/// - Version: 1.0
/// - Date:    14 Dec 2017
class Logger {

    private static let maxLines = 1000
    private let textView: UITextView
    private var numLines = 0
    private var hLogFile: FileHandle?

    /// Creates an instance of `Logger`.
    ///
    /// - Parameter textView: the text view
    init(textView: UITextView) {

        self.textView = textView
        clear()
    }

    /// Opens the log file.
    ///
    /// - Parameter name: the filename
    func openLogFile(name: String) {

        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                        .userDomainMask,
                                                        true)
        let documentsDirectory = paths[0]

        // Create directory "Logs".
        let fileManager = FileManager.default
        var filePath = NSString(string: documentsDirectory)
            .appendingPathComponent("Logs")
        if !fileManager.fileExists(atPath: filePath) {
            do {
                try fileManager.createDirectory(
                    atPath: filePath,
                    withIntermediateDirectories: true)
            } catch {}
        }

        // Create the log file.
        filePath = NSString(string: filePath).appendingPathComponent(name)
        if !fileManager.fileExists(atPath: filePath) {
            fileManager.createFile(atPath: filePath,
                                   contents: nil,
                                   attributes: nil)
        }

        // Open the log file.
        closeLogFile()
        hLogFile = FileHandle(forWritingAtPath: filePath)
        if hLogFile != nil {
            hLogFile!.seekToEndOfFile()
        }
    }

    /// Closes the log file.
    func closeLogFile() {

        if hLogFile != nil {

            hLogFile!.closeFile()
            hLogFile = nil
        }
    }

    /// Logs the message.
    ///
    /// - Parameters:
    ///   - format: the format
    ///   - arguments: the arguments
    func logMsg(_ format: String, _ arguments: CVarArg...) {

        let msg = String(format: format, arguments: arguments)
        #if DEBUG
            print(msg)
        #endif

        let textView = self.textView
        DispatchQueue.main.async {

            // Append the message to the text view.
            textView.text.append("\(msg)\n")
            self.numLines += 1

            // Remove the first line from the text view.
            if self.numLines > Logger.maxLines {
                if let index = textView.text.firstIndex(of: "\n") {

                    let startIndex = textView.text.startIndex
                    textView.text.removeSubrange(startIndex...index)
                    self.numLines -= 1
                }
            }

            // Scroll the text view.
            let range = NSMakeRange((textView.text as NSString).length - 1, 1)
            textView.scrollRangeToVisible(range)
        }

        if let hLogFile = hLogFile {

            let currentDate = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "[dd-MM-yyyy HH:mm:ss]"
            let log = "\(dateFormatter.string(from: currentDate)): \(msg)\n"
            if let data = log.data(using: .ascii) {

                hLogFile.write(data)
                hLogFile.synchronizeFile()
            }
        }
    }

    /// Logs the contents of buffer.
    ///
    /// - Parameter buffer: the buffer
    func logBuffer(_ buffer: [UInt8]) {
        logBuffer(buffer, offset: 0, byteCount: buffer.count)
    }

    /// Logs the contents of buffer.
    ///
    /// - Parameters:
    ///   - buffer: the buffer
    ///   - offset: the offset
    ///   - byteCount: the byte count
    func logBuffer(_ buffer: [UInt8], offset: Int, byteCount: Int) {

        var bufferString = ""

        // Check the parameter.
        if offset < 0
            || byteCount < 0
            || offset + byteCount > buffer.count {
            return
        }

        for i in 0..<byteCount {

            if i % 16 == 0 {
                if !bufferString.isEmpty {

                    logMsg(bufferString)
                    bufferString = ""
                }
            }

            if i % 16 == 0 {
                bufferString += String(format: "%02X", buffer[offset + i])
            } else {
                bufferString += String(format: " %02X", buffer[offset + i])
            }
        }

        if !bufferString.isEmpty {
            logMsg(bufferString)
        }
    }

    /// Logs the HEX string.
    ///
    /// - Parameter hexString: the HEX string
    func logHexString(_ hexString: String) {

        var first = true
        var tmpString = ""
        var i = 0

        for c in hexString {

            if c >= Character("0") && c <= Character("9")
                || c >= Character("A") && c <= Character("F")
                || c >= Character("a") && c <= Character("f")
                || c == Character("X")
                || c == Character("x") {

                if first {
                    if (i != 0) {
                        tmpString += " "
                    }
                }

                tmpString += String(c)
                i += 1

                first = !first

                if i >= 2 * 16 {

                    logMsg(tmpString)
                    tmpString = ""
                    i = 0
                }
            }
        }

        if i > 0 {
            logMsg(tmpString)
        }
    }

    /// Clears the log messages.
    func clear() {

        DispatchQueue.main.async {

            self.textView.text = ""
            self.numLines = 0
        }
    }
}

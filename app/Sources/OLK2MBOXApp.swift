/*
 Artifact-Version: 2.0.1
 Release-Date: 2026-09-08
 Stability: Stable
 Change-Summary: Make process-output callbacks compatible with strict Swift concurrency checking.
 SPDX-FileCopyrightText: 2026 igp76
 SPDX-License-Identifier: GPL-3.0-or-later
 */

import AppKit
import Combine
import SwiftUI

private let applicationVersion = "2.0.0"
private let embeddedEngineVersion = "2.0.0"

enum LogLevel: String, CaseIterable, Identifiable {
    case concise, normal, detailed, extreme

    var id: String { rawValue }
    var progressInterval: Int {
        switch self {
        case .concise: return 1_000
        case .normal: return 250
        case .detailed: return 50
        case .extreme: return 1
        }
    }
    var localizedTitle: String {
        switch self {
        case .concise: return String(localized: "Concise")
        case .normal: return String(localized: "Normal")
        case .detailed: return String(localized: "Detailed")
        case .extreme: return String(localized: "Extreme")
        }
    }
}

@MainActor
final class OLK2MBOXModel: ObservableObject {
    @Published var profilePath = ""
    @Published var outputPath = ""
    @Published var includeAttachments = true
    @Published var excludeHidden = false
    @Published var excludeDeleted = false
    @Published var continueOnError = true
    @Published var overwrite = false
    @Published var logLevel = LogLevel.normal
    @Published var autoScroll = true
    @Published var isRunning = false
    @Published var status = String(localized: "Ready")
    @Published var logText = ""
    @Published var logSequence = 0
    @Published var processedMessages = 0
    @Published var totalMessages: Int?
    @Published var clock = Date()

    private let displayLogCharacterLimit = 2_000_000
    private var process: Process?
    private var pipe: Pipe?
    private var executionLogHandle: FileHandle?
    private var executionLogURL: URL?
    private var errorLogURL: URL?
    private var startedAt: Date?
    private var lineBuffer = ""
    private var stopRequested = false

    var canStart: Bool {
        !isRunning && !profilePath.isEmpty && !outputPath.isEmpty && helperURL != nil
    }

    var progressFraction: Double? {
        guard let totalMessages, totalMessages > 0 else { return nil }
        return min(max(Double(processedMessages) / Double(totalMessages), 0), 1)
    }

    var progressSummary: String {
        guard let totalMessages else { return String(localized: "Preparing conversion…") }
        return String(
            format: String(localized: "%lld of %lld messages processed"),
            processedMessages,
            totalMessages
        )
    }

    var timingSummary: String? {
        guard let startedAt else { return nil }
        let elapsed = max(clock.timeIntervalSince(startedAt), 0)
        let elapsedText = formatDuration(elapsed)
        guard isRunning, let totalMessages, processedMessages > 0, processedMessages < totalMessages else {
            return String(format: String(localized: "Elapsed: %@"), elapsedText)
        }
        let remaining = elapsed * Double(totalMessages - processedMessages) / Double(processedMessages)
        return String(
            format: String(localized: "Elapsed: %@ · Estimated remaining: %@"),
            elapsedText,
            formatDuration(remaining)
        )
    }

    private var helperURL: URL? {
        let candidate = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("olk2mbox", isDirectory: false)
        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
    }

    func chooseProfile() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose Outlook profile")
        panel.message = String(localized: "Select the Main Profile folder or its Data folder.")
        panel.prompt = String(localized: "Choose")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        profilePath = url.path
        status = String(localized: "Profile selected")
    }

    func chooseOutput() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose output folder")
        panel.message = String(localized: "Select where the MBOX hierarchy will be created.")
        panel.prompt = String(localized: "Choose")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputPath = url.path
        status = String(localized: "Output selected")
    }

    func startConversion() {
        guard let helperURL else {
            appendDisplay(String(localized: "The embedded converter is missing or not executable.") + "\n")
            status = String(localized: "Cannot start")
            return
        }
        guard !profilePath.isEmpty, !outputPath.isEmpty else { return }

        resetRunState()
        do {
            try prepareRunLogs()
        } catch {
            status = String(localized: "Cannot create logs")
            appendDisplay(error.localizedDescription + "\n")
            return
        }

        let newProcess = Process()
        let newPipe = Pipe()
        var arguments = [profilePath, outputPath, "--progress-every", String(logLevel.progressInterval)]
        if !includeAttachments { arguments.append("--no-attachments") }
        if excludeHidden { arguments.append("--exclude-hidden") }
        if excludeDeleted { arguments.append("--exclude-deleted") }
        if continueOnError { arguments += ["--on-error", "skip"] }
        if overwrite { arguments.append("--overwrite") }

        newProcess.executableURL = helperURL
        newProcess.arguments = arguments
        newProcess.standardOutput = newPipe
        newProcess.standardError = newPipe
        isRunning = true
        status = String(localized: "Converting…")
        process = newProcess
        pipe = newPipe

        newPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let value = String(data: data, encoding: .utf8) else { return }
            guard let model = self else { return }
            Task { @MainActor in model.consumeOutput(value) }
        }
        newProcess.terminationHandler = { [weak self] completedProcess in
            newPipe.fileHandleForReading.readabilityHandler = nil
            let tailData = newPipe.fileHandleForReading.readDataToEndOfFile()
            let tail = String(data: tailData, encoding: .utf8) ?? ""
            guard let model = self else { return }
            Task { @MainActor in
                if !tail.isEmpty { model.consumeOutput(tail) }
                model.finishRun(completedProcess)
            }
        }

        do {
            try newProcess.run()
        } catch {
            newPipe.fileHandleForReading.readabilityHandler = nil
            let message = error.localizedDescription
            writeExecution("ERROR: \(message)\n")
            writeErrorLog(exitStatus: nil, launchError: message)
            closeExecutionLog()
            isRunning = false
            process = nil
            pipe = nil
            status = String(localized: "Cannot start")
            appendDisplay(message + "\n")
        }
    }

    func stopConversion() {
        guard let process, process.isRunning else { return }
        stopRequested = true
        status = String(localized: "Stopping…")
        process.interrupt()
    }

    func openOutput() {
        guard !outputPath.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: outputPath, isDirectory: true))
    }

    func verifyHelper() {
        if helperURL == nil { status = String(localized: "Embedded converter unavailable") }
    }

    private func resetRunState() {
        closeExecutionLog()
        logText = ""
        logSequence += 1
        processedMessages = 0
        totalMessages = nil
        startedAt = Date()
        clock = startedAt ?? Date()
        lineBuffer = ""
        stopRequested = false
        executionLogURL = nil
        errorLogURL = nil
    }

    private func prepareRunLogs() throws {
        let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let runIdentifier = formatter.string(from: startedAt ?? Date())
        let baseName = "OLK2MBOX-\(runIdentifier)"
        let executionURL = outputURL.appendingPathComponent("\(baseName)-execution.log")
        let errorsURL = outputURL.appendingPathComponent("\(baseName)-errors.log")

        guard FileManager.default.createFile(atPath: executionURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        executionLogHandle = try FileHandle(forWritingTo: executionURL)
        executionLogURL = executionURL
        errorLogURL = errorsURL

        let header = """
        OLK2MBOX execution log
        Artifact-Version: 2.0.0
        Release-Date: 2026-09-06
        Stability: Stable
        Change-Summary: Stable GPL-3.0-or-later conversion diagnostics.
        License: GPL-3.0-or-later
        App-Version: \(applicationVersion)
        Converter-Version: \(embeddedEngineVersion)
        Started-At: \(ISO8601DateFormatter().string(from: startedAt ?? Date()))
        Profile: \(profilePath)
        Output: \(outputPath)
        Log-Level: \(logLevel.rawValue)
        Progress-Interval: \(logLevel.progressInterval)
        Apple-Code-Signing: Ad hoc; not notarized
        Execution-Log: \(executionURL.path)
        Error-Log: \(errorsURL.path)

        """
        writeExecution(header)
        appendDisplay(header)
    }

    private func consumeOutput(_ value: String) {
        guard !value.isEmpty else { return }
        writeExecution(value)
        appendDisplay(value)
        lineBuffer += value
        let lines = lineBuffer.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count > 1 else { return }
        for line in lines.dropLast() { parseProgressLine(String(line)) }
        lineBuffer = String(lines.last ?? "")
    }

    private func parseProgressLine(_ line: String) {
        if let count = number(in: line, after: "Messages selected: ") {
            totalMessages = count
        } else if let count = number(in: line, after: "Processed ") {
            processedMessages = max(processedMessages, count)
        } else if let count = number(in: line, after: "Completed: ") {
            processedMessages = max(processedMessages, count)
        }
        clock = Date()
    }

    private func number(in line: String, after prefix: String) -> Int? {
        guard line.hasPrefix(prefix) else { return nil }
        let remainder = line.dropFirst(prefix.count)
        let token = remainder.prefix { $0.isNumber || $0 == "," || $0 == "." }
        return Int(token.filter(\.isNumber))
    }

    private func finishRun(_ completedProcess: Process) {
        if !lineBuffer.isEmpty {
            parseProgressLine(lineBuffer)
            lineBuffer = ""
        }
        let exitStatus = completedProcess.terminationStatus
        let completionMessage: String
        if stopRequested {
            status = String(localized: "Conversion stopped")
            completionMessage = String(localized: "The conversion was stopped.")
        } else if exitStatus == 0 {
            if let totalMessages { processedMessages = totalMessages }
            status = String(localized: "Conversion completed")
            completionMessage = String(localized: "The conversion completed successfully.")
        } else if completedProcess.terminationReason == .uncaughtSignal {
            status = String(localized: "Conversion stopped")
            completionMessage = String(localized: "The conversion was stopped.")
        } else {
            status = String(localized: "Conversion failed")
            completionMessage = String(
                format: String(localized: "The converter exited with status %d."),
                exitStatus
            )
        }
        let finalLine = "\n\(completionMessage)\n"
        writeExecution(finalLine)
        appendDisplay(finalLine)
        writeErrorLog(exitStatus: exitStatus, launchError: nil)
        closeExecutionLog()
        isRunning = false
        process = nil
        pipe = nil
        clock = Date()
    }

    private func writeExecution(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        do { try executionLogHandle?.write(contentsOf: data) }
        catch { appendDisplay("Unable to write execution log: \(error.localizedDescription)\n") }
    }

    private func closeExecutionLog() {
        try? executionLogHandle?.synchronize()
        try? executionLogHandle?.close()
        executionLogHandle = nil
    }

    private func writeErrorLog(exitStatus: Int32?, launchError: String?) {
        guard let errorLogURL else { return }
        var output = """
        OLK2MBOX error log
        Artifact-Version: 2.0.0
        Release-Date: 2026-09-06
        Stability: Stable
        Change-Summary: Stable GPL-3.0-or-later conversion-error diagnostics.
        License: GPL-3.0-or-later
        App-Version: \(applicationVersion)
        Converter-Version: \(embeddedEngineVersion)
        Finished-At: \(ISO8601DateFormatter().string(from: Date()))
        Exit-Status: \(exitStatus.map(String.init) ?? "not-started")
        Stopped-By-User: \(stopRequested ? "yes" : "no")

        """
        if let launchError {
            output += "Launch error:\n\(launchError)\n"
        } else {
            let manifestURL = URL(fileURLWithPath: outputPath, isDirectory: true)
                .appendingPathComponent("OLK2MBOX-conversion-manifest.json")
            do {
                let data = try Data(contentsOf: manifestURL)
                let object = try JSONSerialization.jsonObject(with: data)
                let errors = (object as? [String: Any])?["errors"] as? [Any] ?? []
                if errors.isEmpty {
                    output += "No errors recorded.\n"
                } else {
                    output += "Errors recorded: \(errors.count)\n\n"
                    for (index, errorObject) in errors.enumerated() {
                        output += "Error \(index + 1):\n"
                        if JSONSerialization.isValidJSONObject(errorObject),
                           let data = try? JSONSerialization.data(
                               withJSONObject: errorObject,
                               options: [.prettyPrinted, .sortedKeys]
                           ),
                           let text = String(data: data, encoding: .utf8) {
                            output += text + "\n\n"
                        } else {
                            output += String(describing: errorObject) + "\n\n"
                        }
                    }
                }
            } catch {
                let prefix: String
                if stopRequested {
                    prefix = "Conversion was stopped and no readable manifest was available"
                } else if exitStatus == 0 {
                    prefix = "No readable conversion manifest was available"
                } else {
                    prefix = "Conversion failed and no readable manifest was available"
                }
                output += "\(prefix): \(error.localizedDescription)\n"
            }
        }
        do { try output.write(to: errorLogURL, atomically: true, encoding: .utf8) }
        catch {
            let message = "Unable to write error log: \(error.localizedDescription)\n"
            writeExecution(message)
            appendDisplay(message)
        }
    }

    private func appendDisplay(_ value: String) {
        guard !value.isEmpty else { return }
        logText += value
        if logText.count > displayLogCharacterLimit {
            let excess = logText.count - displayLogCharacterLimit
            let provisionalIndex = logText.index(logText.startIndex, offsetBy: excess)
            let newlineIndex = logText[provisionalIndex...].firstIndex(of: "\n") ?? provisionalIndex
            let nextIndex = newlineIndex < logText.endIndex ? logText.index(after: newlineIndex) : newlineIndex
            logText = String(localized: "Earlier output remains available in the execution log.")
                + "\n" + String(logText[nextIndex...])
        }
        logSequence += 1
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3_600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: interval) ?? "—"
    }
}

struct OLK2MBOXView: View {
    @StateObject private var model = OLK2MBOXModel()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            pathSelector(title: String(localized: "Outlook profile"), placeholder: String(localized: "Select Main Profile or Data"), value: $model.profilePath, action: model.chooseProfile)
            pathSelector(title: String(localized: "MBOX destination"), placeholder: String(localized: "Select an output folder"), value: $model.outputPath, action: model.chooseOutput)
            options
            progressAndLog
            controls
        }
        .padding(24)
        .frame(minWidth: 840, minHeight: 620)
        .onAppear(perform: model.verifyHelper)
        .onReceive(timer) { date in if model.isRunning { model.clock = date } }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "envelope.arrow.triangle.branch")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text("OLK2MBOX").font(.title.bold())
                Text("Convert legacy Outlook for Mac profiles into standard MBOX files.").foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("v\(applicationVersion)")
                Text("GPL-3.0-or-later").font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func pathSelector(title: String, placeholder: String, value: Binding<String>, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            HStack {
                TextField(placeholder, text: value).textFieldStyle(.roundedBorder).disabled(model.isRunning)
                Button("Choose…", action: action).disabled(model.isRunning)
            }
        }
    }

    private var options: some View {
        GroupBox("Options") {
            VStack(alignment: .leading, spacing: 12) {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    GridRow {
                        Toggle("Include attachments", isOn: $model.includeAttachments)
                        Toggle("Continue after damaged messages", isOn: $model.continueOnError)
                    }
                    GridRow {
                        Toggle("Exclude hidden messages", isOn: $model.excludeHidden)
                        Toggle("Replace existing MBOX files", isOn: $model.overwrite)
                    }
                    GridRow {
                        Toggle("Exclude messages marked for deletion", isOn: $model.excludeDeleted)
                        Color.clear.frame(height: 1)
                    }
                }.toggleStyle(.checkbox)
                HStack {
                    Text("Log detail")
                    Picker("Log detail", selection: $model.logLevel) {
                        ForEach(LogLevel.allCases) { level in Text(level.localizedTitle).tag(level) }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(maxWidth: 440)
                }
            }
            .padding(.top, 4)
            .disabled(model.isRunning)
        }
    }

    private var progressAndLog: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.status).font(.headline)
                Spacer()
                if let timingSummary = model.timingSummary {
                    Text(timingSummary).font(.callout).foregroundStyle(.secondary)
                }
            }
            if let progressFraction = model.progressFraction {
                ProgressView(value: progressFraction, total: 1)
            } else if model.isRunning {
                ProgressView()
            } else {
                ProgressView(value: 0, total: 1)
            }
            Text(model.progressSummary).font(.callout).foregroundStyle(.secondary)
            ScrollViewReader { proxy in
                VStack(spacing: 6) {
                    ScrollView([.vertical, .horizontal]) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(model.logText.isEmpty ? String(localized: "Log output will appear here.") : model.logText)
                                .font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Color.clear.frame(width: 1, height: 1).id("log-end")
                        }.padding(8)
                    }
                    .frame(minHeight: 150)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
                    .onChange(of: model.logSequence) { _ in
                        if model.autoScroll { proxy.scrollTo("log-end", anchor: .bottom) }
                    }
                    HStack {
                        Toggle("Follow latest output", isOn: $model.autoScroll).toggleStyle(.checkbox)
                        Spacer()
                        Button("Jump to latest") { proxy.scrollTo("log-end", anchor: .bottom) }
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack {
            Button("Open destination", action: model.openOutput).disabled(model.outputPath.isEmpty || model.isRunning)
            Spacer()
            if model.isRunning { Button("Stop", role: .destructive, action: model.stopConversion) }
            Button("Start conversion", action: model.startConversion)
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!model.canStart)
        }
    }
}

@main
struct OLK2MBOXApp: App {
    var body: some Scene {
        WindowGroup { OLK2MBOXView() }
            .windowStyle(.titleBar)
            .commands { CommandGroup(replacing: .newItem) {} }
    }
}

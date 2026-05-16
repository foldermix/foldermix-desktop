import AppKit

struct ExtensionChoice {
    let ext: String
    var enabled: Bool
    var count: Int
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class MainWindowController: NSWindowController {
    private let folderField = NSTextField(labelWithString: "No folder selected")
    private let outputField = NSTextField(string: "")
    private let formatPopup = NSPopUpButton()
    private let extensionContainer = FlippedView()
    private let addExtensionField = NSTextField(string: "")
    private let terminalView = NSTextView()
    private let previewButton = NSButton(title: "Preview", target: nil, action: nil)
    private let runButton = NSButton(title: "Run", target: nil, action: nil)
    private var selectedFolder: URL?
    private var choices: [String: ExtensionChoice] = [:]
    private var orderedExtensions: [String] = []
    private var defaultOutputStamp = MainWindowController.timestamp()
    private let terminalTextColor = NSColor(calibratedWhite: 0.92, alpha: 1)
    private let terminalBackgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1)
    private let terminalFontSize: CGFloat = 15
    private let controlsWidth: CGFloat = 380
    private let primaryButtonHeight: CGFloat = 34

    init() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "foldermix"
        window.minSize = NSSize(width: 1080, height: 640)
        super.init(window: window)
        buildUI(in: window)
        window.setFrame(screenFrame, display: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI(in window: NSWindow) {
        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let controls = makeControls()
        let terminal = makeTerminal()
        controls.translatesAutoresizingMaskIntoConstraints = false
        terminal.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(controls)
        contentView.addSubview(terminal)
        controls.setContentHuggingPriority(.required, for: .horizontal)
        controls.setContentCompressionResistancePriority(.required, for: .horizontal)
        terminal.setContentHuggingPriority(.defaultLow, for: .horizontal)
        terminal.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            controls.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            controls.widthAnchor.constraint(equalToConstant: controlsWidth),
            controls.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16),
            terminal.leadingAnchor.constraint(equalTo: controls.trailingAnchor, constant: 16),
            terminal.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            terminal.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            terminal.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            terminal.widthAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])
    }

    private func makeControls() -> NSView {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 12

        let title = NSTextField(labelWithString: "Foldermix: Pack a Folder")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        title.maximumNumberOfLines = 1

        let subtitle = NSTextField(
            wrappingLabelWithString: "foldermix packs a local folder into one LLM-friendly context artifact you can inspect, share, or pipe into automation."
        )
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 3
        subtitle.widthAnchor.constraint(equalToConstant: controlsWidth - 20).isActive = true

        let selectButton = NSButton(title: "Select Folder", target: self, action: #selector(selectFolder))
        selectButton.bezelStyle = .rounded
        configurePrimaryButton(selectButton, width: 170)
        folderField.lineBreakMode = .byTruncatingMiddle
        folderField.maximumNumberOfLines = 2

        let folderBox = NSStackView(views: [selectButton, folderField])
        folderBox.orientation = .vertical
        folderBox.alignment = .leading
        folderBox.spacing = 6

        formatPopup.addItems(withTitles: ["md", "xml", "jsonl"])
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)

        let formatRow = labeledRow(label: "Format", view: formatPopup)

        outputField.placeholderString = "Output path"
        outputField.isEditable = true
        outputField.lineBreakMode = .byTruncatingMiddle
        let chooseOut = NSButton(title: "Change...", target: self, action: #selector(selectOutput))
        chooseOut.bezelStyle = .rounded
        let outputRow = NSStackView(views: [outputField, chooseOut])
        outputRow.orientation = .horizontal
        outputRow.spacing = 8
        outputRow.alignment = .centerY
        outputField.widthAnchor.constraint(greaterThanOrEqualToConstant: 230).isActive = true

        let extTitle = NSTextField(labelWithString: "File extensions to pack")
        extTitle.font = .systemFont(ofSize: 13, weight: .semibold)

        extensionContainer.frame = NSRect(x: 0, y: 0, width: controlsWidth - 22, height: 260)
        let extScroll = NSScrollView()
        extScroll.borderType = .bezelBorder
        extScroll.hasVerticalScroller = true
        extScroll.documentView = extensionContainer
        extScroll.translatesAutoresizingMaskIntoConstraints = false
        extScroll.heightAnchor.constraint(equalToConstant: 260).isActive = true
        extScroll.widthAnchor.constraint(equalToConstant: controlsWidth - 20).isActive = true

        addExtensionField.placeholderString = ".txt"
        addExtensionField.target = self
        addExtensionField.action = #selector(addExtension)
        let addButton = NSButton(title: "Add", target: self, action: #selector(addExtension))
        addButton.bezelStyle = .rounded
        let addRow = NSStackView(views: [addExtensionField, addButton])
        addRow.orientation = .horizontal
        addRow.spacing = 8
        addExtensionField.widthAnchor.constraint(equalToConstant: 250).isActive = true

        previewButton.target = self
        previewButton.action = #selector(preview)
        previewButton.bezelStyle = .rounded
        configurePrimaryButton(previewButton, width: 110)
        runButton.target = self
        runButton.action = #selector(runPack)
        runButton.bezelStyle = .rounded
        runButton.keyEquivalent = "\r"
        configurePrimaryButton(runButton, width: 90)
        let actionRow = NSStackView(views: [previewButton, runButton])
        actionRow.orientation = .horizontal
        actionRow.spacing = 8

        for view in [title, subtitle, folderBox, formatRow, outputRow, extTitle, extScroll, addRow, actionRow] {
            panel.addArrangedSubview(view)
        }
        renderExtensions()
        return panel
    }

    private func makeTerminal() -> NSView {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.alignment = .width
        panel.distribution = .fill
        panel.spacing = 8

        let title = NSTextField(labelWithString: "Preview and Logs")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.alignment = .center
        terminalView.isEditable = false
        terminalView.font = .monospacedSystemFont(ofSize: terminalFontSize, weight: .regular)
        terminalView.textColor = terminalTextColor
        terminalView.backgroundColor = terminalBackgroundColor
        terminalView.isRichText = false
        terminalView.isVerticallyResizable = true
        terminalView.isHorizontallyResizable = true
        terminalView.minSize = NSSize(width: 0, height: 0)
        terminalView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        terminalView.autoresizingMask = [.width, .height]
        terminalView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        terminalView.textContainer?.widthTracksTextView = false
        setTerminal("Select a folder, then press Preview.\n")

        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = terminalBackgroundColor
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = terminalView
        scroll.translatesAutoresizingMaskIntoConstraints = false
        panel.addArrangedSubview(title)
        panel.addArrangedSubview(scroll)
        scroll.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scroll.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 520).isActive = true
        return panel
    }

    private func configurePrimaryButton(_ button: NSButton, width: CGFloat) {
        button.font = .systemFont(ofSize: 15, weight: .medium)
        button.controlSize = .large
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: primaryButtonHeight).isActive = true
    }

    private func labeledRow(label: String, view: NSView) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.widthAnchor.constraint(equalToConstant: 72).isActive = true
        let row = NSStackView(views: [labelView, view])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    @objc private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url
            defaultOutputStamp = MainWindowController.timestamp()
            folderField.stringValue = url.path
            updateDefaultOutput()
            appendTerminal("Selected folder: \(url.path)\n")
        }
    }

    @objc private func selectOutput() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultOutputURL()?.lastPathComponent ?? "foldermix-output.\(selectedFormat())"
        panel.allowedContentTypes = []
        if let folder = selectedFolder {
            panel.directoryURL = folder.deletingLastPathComponent()
        }
        if panel.runModal() == .OK, let url = panel.url {
            outputField.stringValue = url.path
        }
    }

    @objc private func formatChanged() {
        updateDefaultOutput()
    }

    @objc private func addExtension() {
        let value = normalizedExtension(addExtensionField.stringValue)
        guard !value.isEmpty else { return }
        if choices[value] == nil {
            choices[value] = ExtensionChoice(ext: value, enabled: true, count: 0)
            orderedExtensions.append(value)
        } else {
            choices[value]?.enabled = true
        }
        addExtensionField.stringValue = ""
        renderExtensions()
        appendTerminal("Added extension filter: \(value)\n")
    }

    @objc private func toggleExtension(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < orderedExtensions.count else { return }
        let ext = orderedExtensions[sender.tag]
        choices[ext]?.enabled = sender.state == .on
    }

    @objc private func preview() {
        guard let folder = selectedFolder else {
            appendTerminal("Choose a folder before previewing.\n")
            return
        }
        setBusy(true)
        setTerminal("\u{001B}[1;36mPreviewing\u{001B}[0m \(folder.path)\n\n")
        let args = scanArgs(for: folder)
        runShell(arguments: ["foldermix", "list"] + args) { [weak self] listResult in
            self?.runShell(arguments: ["foldermix", "skiplist", "--conversion-check"] + args) { skipResult in
                DispatchQueue.main.async {
                    self?.setBusy(false)
                    self?.updateExtensions(from: listResult.output)
                    self?.setTerminal("""
                    \u{001B}[1;36m$ foldermix list \(folder.path)\u{001B}[0m
                    \u{001B}[\(listResult.exitCode == 0 ? "32" : "31")mExit code: \(listResult.exitCode)\u{001B}[0m
                    \(listResult.output)

                    \u{001B}[1;36m$ foldermix skiplist --conversion-check \(folder.path)\u{001B}[0m
                    \u{001B}[\(skipResult.exitCode == 0 ? "32" : "31")mExit code: \(skipResult.exitCode)\u{001B}[0m
                    \(skipResult.output)
                    """)
                }
            }
        }
    }

    @objc private func runPack() {
        guard let folder = selectedFolder else {
            appendTerminal("Choose a folder before running.\n")
            return
        }
        let output = outputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else {
            appendTerminal("Choose an output path before running.\n")
            return
        }
        setBusy(true)
        setTerminal("\u{001B}[1;36mRunning foldermix...\u{001B}[0m\n\n")
        var args = ["pack", folder.path, "--format", selectedFormat(), "--out", output]
        let enabled = enabledExtensions()
        if !enabled.isEmpty {
            args += ["--include-ext", enabled.joined(separator: ",")]
        }
        runShell(arguments: ["foldermix"] + args) { [weak self] result in
            DispatchQueue.main.async {
                self?.setBusy(false)
                self?.appendTerminal("""

                \u{001B}[1;36m$ foldermix \(args.joined(separator: " "))\u{001B}[0m
                \(result.output)

                \u{001B}[\(result.exitCode == 0 ? "32" : "31")mExit code: \(result.exitCode)\u{001B}[0m
                \u{001B}[1;32mOutput:\u{001B}[0m \(output)
                """)
            }
        }
    }

    private func scanArgs(for folder: URL) -> [String] {
        var args = [folder.path]
        let enabled = enabledExtensions()
        if !enabled.isEmpty {
            args += ["--include-ext", enabled.joined(separator: ",")]
        }
        return args
    }

    private func enabledExtensions() -> [String] {
        orderedExtensions.compactMap { ext in
            guard choices[ext]?.enabled == true else { return nil }
            return ext
        }
    }

    private func updateExtensions(from output: String) {
        var counts: [String: Int] = [:]
        for line in stripAnsi(output).split(separator: "\n") {
            let text = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty,
                  !text.hasPrefix("│ Path"),
                  !text.hasPrefix("├"),
                  !text.hasPrefix("╭"),
                  !text.hasPrefix("╰"),
                  !text.hasPrefix("Included"),
                  !text.hasPrefix("No "),
                  !text.contains(" would be included") else { continue }
            let pathText = filePathCandidate(fromPreviewLine: text)
            let url = URL(fileURLWithPath: pathText)
            let ext = normalizedExtension(url.pathExtension)
            guard !ext.isEmpty else { continue }
            counts[ext, default: 0] += 1
        }
        if orderedExtensions.isEmpty {
            orderedExtensions = counts.keys.sorted()
            choices = Dictionary(uniqueKeysWithValues: orderedExtensions.map {
                ($0, ExtensionChoice(ext: $0, enabled: true, count: counts[$0] ?? 0))
            })
        } else {
            for ext in counts.keys where choices[ext] == nil {
                orderedExtensions.append(ext)
                choices[ext] = ExtensionChoice(ext: ext, enabled: true, count: counts[ext] ?? 0)
            }
            orderedExtensions.sort()
            for ext in orderedExtensions {
                choices[ext]?.count = counts[ext] ?? 0
            }
        }
        renderExtensions()
    }

    private func filePathCandidate(fromPreviewLine text: String) -> String {
        if text.hasPrefix("│") {
            let cells = text.split(separator: "│", omittingEmptySubsequences: false)
            if cells.count > 1 {
                return String(cells[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text.components(separatedBy: "  (").first ?? text
    }

    private func renderExtensions() {
        extensionContainer.subviews.forEach { view in
            view.removeFromSuperview()
        }

        let rowHeight: CGFloat = 26
        var y: CGFloat = 8

        if orderedExtensions.isEmpty {
            let label = NSTextField(labelWithString: "Preview will populate detected extensions.")
            label.frame = NSRect(x: 8, y: y, width: controlsWidth - 42, height: rowHeight)
            label.textColor = .secondaryLabelColor
            extensionContainer.addSubview(label)
            updateExtensionContainerSize(height: 260)
            return
        }

        for (index, ext) in orderedExtensions.enumerated() {
            guard let choice = choices[ext] else { continue }
            let checkbox = NSButton(checkboxWithTitle: "\(ext)  (\(choice.count))", target: self, action: #selector(toggleExtension(_:)))
            checkbox.frame = NSRect(x: 8, y: y, width: controlsWidth - 42, height: rowHeight)
            checkbox.state = choice.enabled ? .on : .off
            checkbox.tag = index
            checkbox.attributedTitle = NSAttributedString(
                string: "\(ext)  (\(choice.count))",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: NSColor.labelColor
                ]
            )
            extensionContainer.addSubview(checkbox)
            y += rowHeight
        }
        updateExtensionContainerSize(height: max(260, y + 8))
    }

    private func updateExtensionContainerSize(height: CGFloat) {
        extensionContainer.setFrameSize(
            NSSize(
                width: controlsWidth - 22,
                height: height
            )
        )
    }

    private func updateDefaultOutput() {
        if let url = defaultOutputURL() {
            outputField.stringValue = url.path
        }
    }

    private func defaultOutputURL() -> URL? {
        guard let folder = selectedFolder else { return nil }
        let folderSlug = MainWindowController.filenameSlug(folder.lastPathComponent)
        return folder.deletingLastPathComponent().appendingPathComponent(
            "foldermix-\(defaultOutputStamp)-\(folderSlug).\(selectedFormat())"
        )
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func filenameSlug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars).replacingOccurrences(
            of: "-+",
            with: "-",
            options: .regularExpression
        )
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return trimmed.isEmpty ? "output" : trimmed
    }

    private func selectedFormat() -> String {
        formatPopup.titleOfSelectedItem ?? "md"
    }

    private func normalizedExtension(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let withoutDot = trimmed.hasPrefix(".") ? String(trimmed.dropFirst()) : trimmed
        return "." + withoutDot.lowercased()
    }

    private func terminalAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: terminalFontSize, weight: .regular),
            .foregroundColor: terminalTextColor
        ]
    }

    private func setTerminal(_ text: String) {
        terminalView.textStorage?.setAttributedString(attributedTerminalText(text))
        terminalView.scrollToBeginningOfDocument(nil)
    }

    private func appendTerminal(_ text: String) {
        terminalView.textStorage?.append(attributedTerminalText(text))
        terminalView.scrollToEndOfDocument(nil)
    }

    private func attributedTerminalText(_ text: String) -> NSAttributedString {
        let output = NSMutableAttributedString()
        var index = text.startIndex
        var currentColor = terminalTextColor
        var isBold = false

        func append(_ chunk: String) {
            let font = NSFont.monospacedSystemFont(
                ofSize: terminalFontSize,
                weight: isBold ? .bold : .regular
            )
            output.append(
                NSAttributedString(
                    string: chunk,
                    attributes: [.font: font, .foregroundColor: currentColor]
                )
            )
        }

        while index < text.endIndex {
            guard text[index] == "\u{001B}",
                  text.index(after: index) < text.endIndex,
                  text[text.index(after: index)] == "[",
                  let end = text[index...].firstIndex(of: "m") else {
                let next = text[index...].firstIndex(of: "\u{001B}") ?? text.endIndex
                append(String(text[index..<next]))
                index = next
                continue
            }

            let codeStart = text.index(index, offsetBy: 2)
            let codes = String(text[codeStart..<end])
                .split(separator: ";", omittingEmptySubsequences: false)
                .compactMap { Int($0) }
            applyAnsi(codes.isEmpty ? [0] : codes, color: &currentColor, isBold: &isBold)
            index = text.index(after: end)
        }
        return output
    }

    private func stripAnsi(_ text: String) -> String {
        var output = ""
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "\u{001B}",
               text.index(after: index) < text.endIndex,
               text[text.index(after: index)] == "[",
               let end = text[index...].firstIndex(of: "m") {
                index = text.index(after: end)
                continue
            }
            output.append(text[index])
            index = text.index(after: index)
        }
        return output
    }

    private func applyAnsi(_ codes: [Int], color: inout NSColor, isBold: inout Bool) {
        var index = 0
        while index < codes.count {
            let code = codes[index]
            switch code {
            case 0:
                color = terminalTextColor
                isBold = false
            case 1:
                isBold = true
            case 22:
                isBold = false
            case 30...37, 90...97:
                color = ansiColor(code)
            case 39:
                color = terminalTextColor
            case 38 where index + 2 < codes.count && codes[index + 1] == 5:
                color = ansi256Color(codes[index + 2])
                index += 2
            default:
                break
            }
            index += 1
        }
    }

    private func ansiColor(_ code: Int) -> NSColor {
        switch code {
        case 30: NSColor(calibratedWhite: 0.45, alpha: 1)
        case 31: NSColor(calibratedRed: 0.95, green: 0.33, blue: 0.33, alpha: 1)
        case 32: NSColor(calibratedRed: 0.38, green: 0.82, blue: 0.46, alpha: 1)
        case 33: NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.32, alpha: 1)
        case 34: NSColor(calibratedRed: 0.36, green: 0.62, blue: 0.98, alpha: 1)
        case 35: NSColor(calibratedRed: 0.78, green: 0.48, blue: 0.98, alpha: 1)
        case 36: NSColor(calibratedRed: 0.25, green: 0.82, blue: 0.85, alpha: 1)
        case 37: NSColor(calibratedWhite: 0.86, alpha: 1)
        case 90: NSColor(calibratedWhite: 0.55, alpha: 1)
        case 91: NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.45, alpha: 1)
        case 92: NSColor(calibratedRed: 0.5, green: 0.92, blue: 0.58, alpha: 1)
        case 93: NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.42, alpha: 1)
        case 94: NSColor(calibratedRed: 0.48, green: 0.72, blue: 1.0, alpha: 1)
        case 95: NSColor(calibratedRed: 0.88, green: 0.58, blue: 1.0, alpha: 1)
        case 96: NSColor(calibratedRed: 0.42, green: 0.92, blue: 0.95, alpha: 1)
        case 97: NSColor(calibratedWhite: 0.98, alpha: 1)
        default: terminalTextColor
        }
    }

    private func ansi256Color(_ code: Int) -> NSColor {
        if code < 16 {
            return ansiColor(code < 8 ? code + 30 : code + 82)
        }
        if code >= 232 {
            let value = CGFloat(8 + (code - 232) * 10) / 255
            return NSColor(calibratedWhite: value, alpha: 1)
        }
        let adjusted = code - 16
        let red = CGFloat(adjusted / 36) / 5
        let green = CGFloat((adjusted % 36) / 6) / 5
        let blue = CGFloat(adjusted % 6) / 5
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }

    private func setBusy(_ busy: Bool) {
        previewButton.isEnabled = !busy
        runButton.isEnabled = !busy
    }

    private func runShell(arguments: [String], completion: @escaping (CommandResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let resolvedArguments = self.resolveCommand(arguments)
            let pathPrefix = "export PATH=\"$HOME/.pyenv/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH\"; "
            let command = pathPrefix + resolvedArguments.map(shellQuote).joined(separator: " ")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            var environment = ProcessInfo.processInfo.environment
            environment["TERM"] = "xterm-256color"
            environment["CLICOLOR_FORCE"] = "1"
            environment["FORCE_COLOR"] = "1"
            environment["COLUMNS"] = "200"
            process.environment = environment
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let output = String(data: data, encoding: .utf8) ?? ""
                completion(CommandResult(output: output, exitCode: process.terminationStatus))
            } catch {
                completion(CommandResult(output: "Failed to run command: \(error.localizedDescription)\n", exitCode: -1))
            }
        }
    }

    private func resolveCommand(_ arguments: [String]) -> [String] {
        guard arguments.first == "foldermix" else { return arguments }
        var resolved = arguments
        if let bundledFoldermix = bundledFoldermixExecutable() {
            resolved[0] = bundledFoldermix.path
        }
        return resolved
    }

    private func bundledFoldermixExecutable() -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let candidate = resourceURL
            .appendingPathComponent("bin")
            .appendingPathComponent("foldermix-cli")
            .appendingPathComponent("foldermix-cli")
        guard FileManager.default.isExecutableFile(atPath: candidate.path) else { return nil }
        return candidate
    }
}

struct CommandResult {
    let output: String
    let exitCode: Int32
}

private func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

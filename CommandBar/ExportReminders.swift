#!/usr/bin/env swift

import EventKit
import Foundation

// MARK: - Reminders Exporter

class RemindersExporter {
    private let eventStore = EKEventStore()
    private var outputDirectory: URL
    
    init(outputPath: String) {
        // Expand tilde and resolve path
        let expandedPath = NSString(string: outputPath).expandingTildeInPath
        self.outputDirectory = URL(fileURLWithPath: expandedPath)
    }
    
    func export() async throws {
        print("🔐 Requesting reminders access...")
        
        // Request access to reminders
        let granted = try await eventStore.requestFullAccessToReminders()
        
        guard granted else {
            print("❌ Access to reminders denied. Please grant access in System Settings > Privacy & Security > Reminders")
            return
        }
        
        print("✅ Access granted")
        
        // Create output directory if needed
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        
        // Fetch all reminder lists
        let calendars = eventStore.calendars(for: .reminder)
        print("📋 Found \(calendars.count) reminder lists")
        
        var totalReminders = 0
        
        for calendar in calendars {
            let reminders = try await fetchReminders(from: calendar)
            totalReminders += reminders.count
            
            if !reminders.isEmpty {
                try exportList(calendar: calendar, reminders: reminders)
                print("  ✓ \(calendar.title): \(reminders.count) reminders")
            }
        }
        
        // Create index file
        try createIndexFile(calendars: calendars, totalReminders: totalReminders)
        
        print("\n✅ Export complete!")
        print("📁 Location: \(outputDirectory.path)")
        print("📊 Total: \(totalReminders) reminders across \(calendars.count) lists")
    }
    
    private func fetchReminders(from calendar: EKCalendar) async throws -> [EKReminder] {
        let predicate = eventStore.predicateForReminders(in: [calendar])
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
    
    private func exportList(calendar: EKCalendar, reminders: [EKReminder]) throws {
        let markdown = generateMarkdown(for: calendar, reminders: reminders)
        let filename = sanitizeFilename(calendar.title) + ".md"
        let fileURL = outputDirectory.appendingPathComponent(filename)
        
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    private func generateMarkdown(for calendar: EKCalendar, reminders: [EKReminder]) -> String {
        var md = "# \(calendar.title)\n\n"
        md += "**Exported:** \(formatDate(Date()))\n"
        md += "**Total Reminders:** \(reminders.count)\n\n"
        md += "---\n\n"
        
        // Separate completed and incomplete
        let incomplete = reminders.filter { !$0.isCompleted }
        let completed = reminders.filter { $0.isCompleted }
        
        // Incomplete reminders
        if !incomplete.isEmpty {
            md += "## 📌 Active (\(incomplete.count))\n\n"
            for reminder in incomplete.sorted(by: sortReminders) {
                md += formatReminder(reminder)
            }
            md += "\n"
        }
        
        // Completed reminders
        if !completed.isEmpty {
            md += "## ✅ Completed (\(completed.count))\n\n"
            for reminder in completed.sorted(by: sortReminders) {
                md += formatReminder(reminder)
            }
        }
        
        return md
    }
    
    private func formatReminder(_ reminder: EKReminder) -> String {
        var md = ""
        let checkbox = reminder.isCompleted ? "[x]" : "[ ]"
        
        md += "- \(checkbox) **\(reminder.title ?? "Untitled")**\n"
        
        // Priority
        if reminder.priority > 0 && reminder.priority <= 5 {
            let priorityLabel = reminder.priority == 1 ? "🔴 High" : reminder.priority <= 5 ? "🟡 Medium" : "⚪️ Low"
            md += "  - Priority: \(priorityLabel)\n"
        }
        
        // Due date
        if let dueDate = reminder.dueDateComponents {
            if let date = Calendar.current.date(from: dueDate) {
                md += "  - Due: \(formatDate(date))\n"
            }
        }
        
        // Completion date
        if reminder.isCompleted, let completionDate = reminder.completionDate {
            md += "  - Completed: \(formatDate(completionDate))\n"
        }
        
        // Notes
        if let notes = reminder.notes, !notes.isEmpty {
            md += "  - Notes: \(notes.replacingOccurrences(of: "\n", with: " "))\n"
        }
        
        // URL
        if let url = reminder.url {
            md += "  - Link: [\(url.absoluteString)](\(url.absoluteString))\n"
        }
        
        // Creation date
        if let creationDate = reminder.creationDate {
            md += "  - Created: \(formatDate(creationDate))\n"
        }
        
        // Tags (if available)
        if #available(macOS 15.0, *) {
            // Note: EKReminder doesn't directly expose tags in EventKit
            // This is a placeholder for future API support
        }
        
        md += "\n"
        return md
    }
    
    private func createIndexFile(calendars: [EKCalendar], totalReminders: Int) throws {
        var md = "# Reminders Export\n\n"
        md += "**Exported:** \(formatDate(Date()))\n"
        md += "**Total Reminders:** \(totalReminders)\n"
        md += "**Lists:** \(calendars.count)\n\n"
        md += "---\n\n"
        md += "## Lists\n\n"
        
        for calendar in calendars.sorted(by: { $0.title < $1.title }) {
            let filename = sanitizeFilename(calendar.title) + ".md"
            md += "- [\(calendar.title)](\(filename))\n"
        }
        
        let indexURL = outputDirectory.appendingPathComponent("README.md")
        try md.write(to: indexURL, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Helpers
    
    private func sortReminders(_ a: EKReminder, _ b: EKReminder) -> Bool {
        // Sort by: priority (high first), then due date (earliest first), then title
        if a.priority != b.priority {
            // Lower number = higher priority
            return a.priority < b.priority
        }
        
        let aDate = a.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        let bDate = b.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        
        if let aDate, let bDate {
            return aDate < bDate
        } else if aDate != nil {
            return true // a has date, b doesn't
        } else if bDate != nil {
            return false // b has date, a doesn't
        }
        
        return (a.title ?? "") < (b.title ?? "")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name.components(separatedBy: invalidChars).joined(separator: "-")
    }
}

// MARK: - Main Entry Point

@main
struct RemindersExportApp {
    static func main() async {
        print("📱 Reminders → Markdown Exporter\n")
        
        let arguments = CommandLine.arguments
        
        // Parse output directory
        let outputPath: String
        if arguments.count > 1 {
            outputPath = arguments[1]
        } else {
            // Default to ~/Documents/Reminders Export
            outputPath = "~/Documents/Reminders Export"
        }
        
        print("📁 Output directory: \(outputPath)\n")
        
        let exporter = RemindersExporter(outputPath: outputPath)
        
        do {
            try await exporter.export()
        } catch {
            print("\n❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }
}

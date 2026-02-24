import SwiftUI
import AppKit

// MARK: - JSON Structure Analysis

/// Detected rendering hint for a JSON value
enum JsonRenderHint {
    case progressCards       // object with a main array of items that have progress/status
    case statusList          // array of objects with id + boolean/status fields
    case timeline            // array of objects with date/time fields
    case keyValuePairs       // simple object with scalar values
    case arrayOfObjects      // array of uniform objects → table
    case arrayOfScalars      // array of strings/numbers → simple list
    case nestedObject        // complex nested → tree
    case scalar              // single value
}

struct JsonAnalyzer {
    static func analyze(_ value: Any) -> JsonRenderHint {
        if let dict = value as? [String: Any] {
            // Look for a "main array" — the largest array-of-objects value
            if let (_, mainArr) = findMainArray(in: dict), !mainArr.isEmpty {
                let sample = mainArr[0]
                // Items have progress/status/topics → progress cards
                if hasProgressFields(sample) {
                    return .progressCards
                }
                // Items have date + title → timeline (check before statusList, more specific)
                if hasTimelineFields(sample) {
                    return .timeline
                }
                // Items have id + boolean or status → status list
                if hasStatusFields(sample) {
                    return .statusList
                }
            }
            let allScalar = dict.values.allSatisfy { isScalar($0) }
            if allScalar { return .keyValuePairs }
            return .nestedObject
        }
        if let arr = value as? [Any] {
            if let objects = arr as? [[String: Any]], !objects.isEmpty {
                if hasProgressFields(objects[0]) { return .progressCards }
                if hasTimelineFields(objects[0]) { return .timeline }
                if hasStatusFields(objects[0]) { return .statusList }
                return .arrayOfObjects
            }
            if arr.allSatisfy({ isScalar($0) }) { return .arrayOfScalars }
            return .arrayOfObjects
        }
        return .scalar
    }
    
    /// Find the largest array-of-objects field in a dict
    static func findMainArray(in dict: [String: Any]) -> (String, [[String: Any]])? {
        var best: (String, [[String: Any]])? = nil
        var bestScore = 0
        for (key, val) in dict {
            if let arr = val as? [[String: Any]], !arr.isEmpty {
                // Prefer arrays with richer structure (status/progress fields) over just largest
                var score = arr.count
                let sample = arr[0]
                if hasProgressFields(sample) { score += 1000 }
                if hasStatusFields(sample) { score += 500 }
                if hasTimelineFields(sample) { score += 200 }
                if score > bestScore {
                    bestScore = score
                    best = (key, arr)
                }
            }
        }
        return best
    }
    
    /// Find ALL arrays of objects in a dict (for multi-section rendering)
    static func findAllArrays(in dict: [String: Any]) -> [(String, [[String: Any]])] {
        dict.compactMap { key, val in
            if let arr = val as? [[String: Any]], !arr.isEmpty { return (key, arr) }
            return nil
        }.sorted { $0.1.count > $1.1.count }
    }
    
    /// Has progress-like fields: (progress OR completion%) AND (status OR topics/steps)
    static func hasProgressFields(_ obj: [String: Any]) -> Bool {
        let keys = Set(obj.keys)
        let hasProgress = keys.contains("progress") || keys.contains("completion") || keys.contains("percent")
        let hasStatus = keys.contains("status") || keys.contains("state")
        let hasSteps = keys.contains("topics") || keys.contains("steps") || keys.contains("tasks") || keys.contains("items") || keys.contains("children")
        return (hasProgress && hasStatus) || (hasProgress && hasSteps) || (hasStatus && hasSteps)
    }
    
    /// Has status-like fields: id/name + boolean or status
    static func hasStatusFields(_ obj: [String: Any]) -> Bool {
        let keys = Set(obj.keys)
        let hasId = keys.contains("id") || keys.contains("name") || keys.contains("title")
        let hasBool = obj.values.contains(where: { ($0 as? NSNumber)?.isBool == true })
        let hasStatus = keys.contains("status") || keys.contains("passes") || keys.contains("passed") || keys.contains("done") || keys.contains("completed")
        return hasId && (hasBool || hasStatus)
    }
    
    /// Has date/time fields → timeline
    static func hasTimelineFields(_ obj: [String: Any]) -> Bool {
        let keys = Set(obj.keys)
        let hasDate = keys.contains("date") || keys.contains("time") || keys.contains("timestamp")
            || keys.contains("created") || keys.contains("createdAt") || keys.contains("updated")
            || keys.contains("created_at") || keys.contains("updated_at") || keys.contains("completedAt")
            || keys.contains("completed_at") || keys.contains("startDate") || keys.contains("endDate")
        let hasLabel = keys.contains("title") || keys.contains("name") || keys.contains("description")
            || keys.contains("message") || keys.contains("event") || keys.contains("label")
        return hasDate && hasLabel
    }
    
    static func isScalar(_ value: Any) -> Bool {
        value is String || value is NSNumber || value is Bool || value is NSNull
    }
}

extension NSNumber {
    var isBool: Bool { CFBooleanGetTypeID() == CFGetTypeID(self) }
}

// MARK: - Main View

struct JsonReaderView: View {
    let jsonText: String
    
    @State private var parsed: Any?
    @State private var parseError: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let error = parseError {
                    errorView(error)
                } else if let value = parsed {
                    renderRoot(value)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 32)
            .frame(maxWidth: DesignTokens.maxContentWidth + 96, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: DesignTokens.isDark ? NSColor(white: 0.08, alpha: 1) : .white))
        .onAppear { parse() }
        .onChange(of: jsonText) { _, _ in parse() }
    }
    
    private func parse() {
        guard let data = jsonText.data(using: .utf8) else {
            parseError = "Invalid UTF-8"
            return
        }
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            parseError = nil
        } catch {
            parseError = error.localizedDescription
            parsed = nil
        }
    }
    
    @ViewBuilder
    private func renderRoot(_ value: Any) -> some View {
        StructuredDataView(value: value)
    }
    
    private func errorView(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text(msg)
                .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
        }
        .padding()
    }
    
    private func scalarText(_ value: Any) -> some View {
        Text(String(describing: value))
            .font(.system(size: DesignTokens.bodySize))
            .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
    }
}

// MARK: - Progress Dashboard (curriculum.json style)

struct ProgressDashboardView: View {
    let data: [String: Any]
    
    private var mainItems: [[String: Any]] {
        if let (_, arr) = JsonAnalyzer.findMainArray(in: data) { return arr }
        return []
    }
    
    private var title: String {
        // Try common title fields
        for key in ["description", "title", "name", "label"] {
            if let s = data[key] as? String { return s }
        }
        return "Dashboard"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            Text(title)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Color(nsColor: DesignTokens.headingColor))
            
            // Extra scalar metadata (version, etc.)
            if !extraScalars.isEmpty {
                HStack(spacing: 16) {
                    ForEach(extraScalars, id: \.0) { key, value in
                        HStack(spacing: 4) {
                            Text(key)
                                .font(.system(size: 11))
                                .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                            Text(value)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
                        }
                    }
                }
            }
            
            // Summary bar
            summaryBar
            
            // Item cards
            ForEach(Array(mainItems.enumerated()), id: \.offset) { _, item in
                CourseCardView(course: item)
            }
            
            // Extra top-level fields (schedule, rules, etc.)
            ForEach(Array(extraFields.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                if let dict = value as? [String: Any] {
                    metaSection(title: key.capitalized, dict: dict)
                } else if let arr = value as? [String] {
                    rulesSection(arr, title: key.capitalized)
                }
            }
        }
    }
    
    private var summaryBar: some View {
        let items = mainItems
        let total = items.count
        let completed = items.filter { statusString($0) == "completed" }.count
        let active = items.filter { statusString($0) == "active" }.count
        let stepsKey = items.first.flatMap { findStepsKey($0) }
        let totalSteps = stepsKey == nil ? 0 : items.reduce(0) { $0 + (($1[stepsKey!] as? [Any])?.count ?? 0) }
        let doneSteps = items.reduce(0) { $0 + progressValue($1) }
        
        return HStack(spacing: 20) {
            statPill(label: "Total", value: "\(total)", color: .secondary)
            statPill(label: "Done", value: "\(completed)", color: .green)
            statPill(label: "Active", value: "\(active)", color: .blue)
            if totalSteps > 0 {
                statPill(label: "Steps", value: "\(doneSteps)/\(totalSteps)", color: .orange)
            }
        }
        .padding(.vertical, 8)
    }
    
    /// Extra scalar fields (version, etc.) shown as metadata below title
    private var extraScalars: [(String, String)] {
        let mainKey = JsonAnalyzer.findMainArray(in: data)?.0
        let titleKeys: Set<String> = ["description", "title", "name", "label"]
        return data.compactMap { key, val in
            guard key != mainKey && !titleKeys.contains(key) && JsonAnalyzer.isScalar(val) else { return nil }
            return (key, String(describing: val))
        }.sorted(by: { $0.0 < $1.0 })
    }
    
    /// Extra non-scalar fields (schedule dict, rules array, etc.)
    private var extraFields: [String: Any] {
        let mainKey = JsonAnalyzer.findMainArray(in: data)?.0
        let titleKeys: Set<String> = ["description", "title", "name", "label"]
        return data.filter { key, val in
            key != mainKey && !titleKeys.contains(key) && !JsonAnalyzer.isScalar(val)
        }
    }
    
    private func statusString(_ obj: [String: Any]) -> String {
        (obj["status"] as? String) ?? (obj["state"] as? String) ?? ""
    }
    
    private func progressValue(_ obj: [String: Any]) -> Int {
        (obj["progress"] as? Int) ?? (obj["completion"] as? Int) ?? (obj["percent"] as? Int) ?? 0
    }
    
    private func findStepsKey(_ obj: [String: Any]) -> String? {
        for key in ["topics", "steps", "tasks", "items", "children"] {
            if obj[key] is [Any] { return key }
        }
        return nil
    }
    
    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
        }
    }
    
    private func metaSection(title: String, dict: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(nsColor: DesignTokens.headingColor))
            KeyValueView(dict: dict)
        }
        .padding(.top, 8)
    }
    
    private func rulesSection(_ rules: [String], title: String = "Rules") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(nsColor: DesignTokens.headingColor))
            ForEach(Array(rules.enumerated()), id: \.offset) { i, rule in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(i + 1).")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                        .frame(width: 20, alignment: .trailing)
                    Text(rule)
                        .font(.system(size: 13))
                        .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Progress Card (generic)

struct CourseCardView: View {
    let course: [String: Any]
    @State private var expanded = false
    
    private var title: String {
        for k in ["title", "name", "label", "id"] {
            if let s = course[k] as? String { return s }
        }
        return "Untitled"
    }
    private var status: String {
        (course["status"] as? String) ?? (course["state"] as? String) ?? "unknown"
    }
    private var steps: [Any] {
        for k in ["topics", "steps", "tasks", "items", "children"] {
            if let a = course[k] as? [Any] { return a }
        }
        return []
    }
    private var progress: Int {
        (course["progress"] as? Int) ?? (course["completion"] as? Int) ?? 0
    }
    private var sessions: [[String: Any]] { course["sessions"] as? [[String: Any]] ?? [] }
    private var category: String {
        (course["category"] as? String) ?? (course["type"] as? String) ?? ""
    }
    private var subtitle: String {
        for k in ["trigger", "description", "desc", "summary"] {
            if let s = course[k] as? String, s != title { return s }
        }
        return ""
    }
    
    private var fraction: Double {
        steps.isEmpty ? 0 : Double(progress) / Double(steps.count)
    }
    
    private var statusColor: Color {
        switch status {
        case "completed": return .green
        case "active": return .blue
        case "queued": return Color(nsColor: DesignTokens.secondaryColor)
        default: return .gray
        }
    }
    
    private var statusIcon: String {
        switch status {
        case "completed": return "checkmark.circle.fill"
        case "active": return "play.circle.fill"
        case "queued": return "clock"
        default: return "questionmark.circle"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(nsColor: DesignTokens.headingColor))
                Spacer()
                Text(category.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(3)
            }
            
            // Subtitle
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
            }
            
            // Progress bar
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(nsColor: DesignTokens.isDark ? NSColor(white: 0.2, alpha: 1) : NSColor(white: 0.9, alpha: 1)))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(statusColor)
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 4)
                
                Text("\(progress)/\(steps.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                    .frame(width: 36, alignment: .trailing)
            }
            
            // Expandable topics
            if !steps.isEmpty {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                        Text("Details")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                }
                .buttonStyle(.plain)
                
                if expanded {
                    topicsList
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: DesignTokens.isDark ? NSColor(white: 0.11, alpha: 1) : NSColor(white: 0.97, alpha: 1)))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: DesignTokens.isDark ? NSColor(white: 0.18, alpha: 1) : NSColor(white: 0.91, alpha: 1)), lineWidth: 0.5)
        )
    }
    
    private var topicsList: some View {
        let completedIdxs = Set(sessions.compactMap { $0["topicIdx"] as? Int })
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, topic in
                let done = completedIdxs.contains(i) || i < progress
                HStack(spacing: 6) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11))
                        .foregroundColor(done ? .green : Color(nsColor: DesignTokens.secondaryColor))
                    Text(String(describing: topic))
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: done ? DesignTokens.secondaryColor : DesignTokens.bodyColor))
                        .strikethrough(done, color: Color(nsColor: DesignTokens.secondaryColor))
                }
            }
        }
        .padding(.leading, 4)
    }
}

// MARK: - Feature List (features.json style)

struct FeatureListView: View {
    let items: [[String: Any]]
    
    private func isPassed(_ item: [String: Any]) -> Bool {
        // Check boolean fields
        for k in ["passes", "passed", "done", "completed", "success"] {
            if let b = item[k] as? Bool { return b }
            if let n = item[k] as? NSNumber, n.isBool { return n.boolValue }
        }
        // Check status string
        for k in ["status", "state"] {
            if let s = item[k] as? String {
                return ["completed", "done", "passed", "released", "resolved", "closed"].contains(s.lowercased())
            }
        }
        return false
    }
    
    private var passCount: Int {
        items.filter { isPassed($0) }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("\(passCount)/\(items.count) passed")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(passCount == items.count ? .green : .orange)
                ProgressView(value: Double(passCount), total: Double(max(items.count, 1)))
                    .tint(passCount == items.count ? .green : .orange)
            }
            .padding(.bottom, 4)
            
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                featureRow(item)
            }
        }
    }
    
    private func featureRow(_ item: [String: Any]) -> some View {
        // Flexible field lookup
        let id = findString(item, keys: ["id", "code", "key"]) ?? ""
        let title = findString(item, keys: ["title", "name", "label"]) ?? ""
        let desc = findString(item, keys: ["description", "desc", "summary", "detail"]) ?? ""
        let passes = isPassed(item)
        let cat = findString(item, keys: ["category", "type", "group"]) ?? ""
        let status = findString(item, keys: ["status", "state"]) ?? ""
        let note = findString(item, keys: ["note", "comment"])
        
        // Decide what to show as the main label
        let mainLabel: String = {
            if !title.isEmpty { return title }
            if !desc.isEmpty { return desc }
            if !id.isEmpty { return id }
            return "?"
        }()
        // Show id as secondary only if title is the main label
        let showId = !id.isEmpty && !title.isEmpty && id != title
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: passes ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(passes ? .green : .red)
                    .font(.system(size: 13))
                if showId {
                    Text(id)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                }
                Text(mainLabel)
                    .font(.system(size: 13))
                    .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
                    .lineLimit(2)
                Spacer()
                if !status.isEmpty {
                    Text(status)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(statusColor(status))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(statusColor(status).opacity(0.12))
                        .cornerRadius(3)
                }
                if !cat.isEmpty && status.isEmpty {
                    Text(cat)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                }
            }
            // Show description below title if both exist
            if !title.isEmpty && !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                    .padding(.leading, 21)
                    .lineLimit(2)
            }
            if let note = note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                    .padding(.leading, 21)
            }
            // Show extra scalar fields not already displayed (assignee, priority, etc.)
            let knownKeys: Set<String> = ["id", "code", "key", "title", "name", "label",
                "description", "desc", "summary", "detail", "status", "state",
                "category", "type", "group", "note", "comment",
                "passes", "passed", "done", "completed", "success"]
            let extras = item.filter { !knownKeys.contains($0.key) && JsonAnalyzer.isScalar($0.value) }
                .sorted(by: { $0.key < $1.key })
            if !extras.isEmpty {
                HStack(spacing: 12) {
                    ForEach(extras, id: \.key) { key, value in
                        HStack(spacing: 3) {
                            Text(key)
                                .font(.system(size: 10))
                                .foregroundColor(Color(nsColor: DesignTokens.secondaryColor).opacity(0.7))
                            Text(String(describing: value))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                        }
                    }
                }
                .padding(.leading, 21)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func findString(_ dict: [String: Any], keys: [String]) -> String? {
        for k in keys {
            if let s = dict[k] as? String, !s.isEmpty { return s }
        }
        return nil
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "completed", "done", "passed", "released": return .green
        case "active", "in_progress", "current": return .blue
        case "queued", "planned", "upcoming", "pending": return Color(nsColor: DesignTokens.secondaryColor)
        case "failed", "error", "blocked": return .red
        default: return Color(nsColor: DesignTokens.secondaryColor)
        }
    }
}

// MARK: - Key-Value Pairs

struct KeyValueView: View {
    let dict: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(dict.keys.sorted()), id: \.self) { key in
                HStack(alignment: .top, spacing: 8) {
                    Text(key)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                        .frame(minWidth: 80, alignment: .trailing)
                    
                    let str = stringValue(dict[key])
                    if let color = parseHexColor(str) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(nsColor: color))
                            .frame(width: 14, height: 14)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
                    }
                    
                    Text(str)
                        .font(.system(size: 13))
                        .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    private func stringValue(_ v: Any?) -> String {
        guard let v = v else { return "null" }
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        if v is NSNull { return "null" }
        return String(describing: v)
    }
    
    private func parseHexColor(_ s: String) -> NSColor? {
        let hex = s.trimmingCharacters(in: .whitespaces)
        guard hex.hasPrefix("#") else { return nil }
        let stripped = String(hex.dropFirst())
        guard stripped.count == 6 || stripped.count == 8,
              stripped.allSatisfy({ $0.isHexDigit }) else { return nil }
        var val: UInt64 = 0
        Scanner(string: stripped).scanHexInt64(&val)
        if stripped.count == 6 {
            return NSColor(red: CGFloat((val >> 16) & 0xFF) / 255,
                           green: CGFloat((val >> 8) & 0xFF) / 255,
                           blue: CGFloat(val & 0xFF) / 255, alpha: 1)
        } else {
            return NSColor(red: CGFloat((val >> 24) & 0xFF) / 255,
                           green: CGFloat((val >> 16) & 0xFF) / 255,
                           blue: CGFloat((val >> 8) & 0xFF) / 255,
                           alpha: CGFloat(val & 0xFF) / 255)
        }
    }
}

// MARK: - Array Table (uniform objects → table)

struct ArrayTableView: View {
    let items: [[String: Any]]
    
    private var columns: [String] {
        guard let first = items.first else { return [] }
        return Array(first.keys).sorted()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 0) {
                ForEach(columns, id: \.self) { col in
                    Text(col)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
            }
            .background(Color(nsColor: DesignTokens.tableHeaderBackground))
            
            // Rows
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                HStack(spacing: 0) {
                    ForEach(columns, id: \.self) { col in
                        cellView(item[col])
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                    }
                }
                .background(Color(nsColor: i % 2 == 0 ? DesignTokens.tableEvenRow : DesignTokens.tableOddRow))
            }
        }
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(nsColor: DesignTokens.tableBorder), lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private func cellView(_ value: Any?) -> some View {
        if let b = value as? Bool {
            Image(systemName: b ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(b ? .green : .red)
                .font(.system(size: 12))
        } else {
            Text(cellString(value))
                .font(.system(size: 12))
                .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
                .lineLimit(2)
        }
    }
    
    private func cellString(_ v: Any?) -> String {
        guard let v = v else { return "" }
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        if v is NSNull { return "—" }
        if let arr = v as? [Any] { return "[\(arr.count) items]" }
        if let dict = v as? [String: Any] { return "{\(dict.count) keys}" }
        return String(describing: v)
    }
}

// MARK: - Scalar List

struct ScalarListView: View {
    let items: [Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(i + 1)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                        .frame(width: 24, alignment: .trailing)
                    Text(String(describing: item))
                        .font(.system(size: 13))
                        .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
                        .textSelection(.enabled)
                }
            }
        }
    }
}

// MARK: - Nested Object (top-level with mixed values)

struct NestedObjectView: View {
    let dict: [String: Any]
    
    private var sortedKeys: [String] { dict.keys.sorted() }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(sortedKeys, id: \.self) { key in
                sectionView(key: key)
            }
        }
    }
    
    @ViewBuilder
    private func sectionView(key: String) -> some View {
        let value = dict[key]!
        VStack(alignment: .leading, spacing: 6) {
            Text(key)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(nsColor: DesignTokens.headingColor))
            valueView(value, key: key)
        }
    }
    
    @ViewBuilder
    private func valueView(_ value: Any, key: String) -> some View {
        if JsonAnalyzer.isScalar(value) {
            Text(scalarString(value))
                .font(.system(size: 13))
                .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
                .textSelection(.enabled)
        } else if let arr = value as? [String] {
            ScalarListView(items: arr)
        } else if let arr = value as? [[String: Any]] {
            let hint = JsonAnalyzer.analyze(arr)
            switch hint {
            case .progressCards:
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(arr.enumerated()), id: \.offset) { _, item in
                        CourseCardView(course: item)
                    }
                }
            case .timeline:
                TimelineListView(items: arr)
            case .statusList:
                FeatureListView(items: arr)
            default:
                ArrayTableView(items: arr)
            }
        } else if let sub = value as? [String: Any] {
            KeyValueView(dict: sub)
                .padding(.leading, 8)
        } else if let arr = value as? [Any], isNumericArray(arr) {
            // Pure numeric array → sparkline
            let vals = arr.compactMap { ($0 as? NSNumber)?.doubleValue }
            SparklineView(values: vals)
                .frame(maxWidth: 500)
        } else if let arr = value as? [[Any]], isXYPairArray(arr) {
            // Array of [x, y] pairs → sparkline
            SparklineView(pairs: arr)
                .frame(maxWidth: 500)
        } else {
            GenericTreeView(value: value, label: key, depth: 0)
        }
    }
    
    private func isNumericArray(_ arr: [Any]) -> Bool {
        arr.count >= 3 && arr.allSatisfy { $0 is NSNumber && !(($0 as? NSNumber)?.isBool ?? false) }
    }
    
    private func isXYPairArray(_ arr: [[Any]]) -> Bool {
        guard arr.count >= 3 else { return false }
        return arr.allSatisfy { pair in
            pair.count == 2
            && pair[0] is NSNumber && !(pair[0] as? NSNumber)!.isBool
            && pair[1] is NSNumber && !(pair[1] as? NSNumber)!.isBool
        }
    }
    
    private func scalarString(_ v: Any) -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        if v is NSNull { return "null" }
        return String(describing: v)
    }
}

// MARK: - Generic Tree (fallback for any structure)

struct GenericTreeView: View {
    let value: Any
    let label: String
    let depth: Int
    @State private var expanded: Bool? = nil  // nil = use default
    
    private var isExpandable: Bool {
        value is [String: Any] || value is [Any]
    }
    
    private var childCount: Int {
        if let d = value as? [String: Any] { return d.count }
        if let a = value as? [Any] { return a.count }
        return 0
    }
    
    private var childCountLabel: String {
        if value is [String: Any] { return "{\(childCount)}" }
        if value is [Any] { return "[\(childCount)]" }
        return ""
    }
    
    /// Smart default: expand small nodes at shallow depth
    private var isExpanded: Bool {
        if let e = expanded { return e }
        if depth == 0 { return true }
        if depth <= 1 && childCount <= 5 { return true }
        return false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if isExpandable {
                    Button(action: { withAnimation(.easeInOut(duration: 0.15)) { expanded = !isExpanded } }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 12)
                }
                
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                
                if isExpandable {
                    Text(childCountLabel)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(nsColor: DesignTokens.secondaryColor).opacity(0.6))
                } else {
                    Text(scalarDisplay(value))
                        .font(.system(size: 12))
                        .foregroundColor(valueColor(value))
                        .textSelection(.enabled)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    if let dict = value as? [String: Any] {
                        ForEach(Array(dict.keys.sorted()), id: \.self) { key in
                            GenericTreeView(value: dict[key]!, label: key, depth: depth + 1)
                        }
                    } else if let arr = value as? [Any] {
                        ForEach(Array(arr.enumerated()), id: \.offset) { i, item in
                            GenericTreeView(value: item, label: "[\(i)]", depth: depth + 1)
                        }
                    }
                }
                .padding(.leading, 16)
            }
        }
    }
    
    private func scalarDisplay(_ v: Any) -> String {
        if let s = v as? String { return "\"\(s)\"" }
        if let n = v as? NSNumber {
            if CFBooleanGetTypeID() == CFGetTypeID(n) {
                return n.boolValue ? "true" : "false"
            }
            return n.stringValue
        }
        if v is NSNull { return "null" }
        return String(describing: v)
    }
    
    private func valueColor(_ v: Any) -> Color {
        if v is String { return Color(.systemGreen) }
        if let n = v as? NSNumber {
            if CFBooleanGetTypeID() == CFGetTypeID(n) {
                return n.boolValue ? Color(.systemBlue) : Color(.systemRed)
            }
            return Color(.systemOrange)
        }
        if v is NSNull { return Color(nsColor: DesignTokens.secondaryColor) }
        return Color(nsColor: DesignTokens.bodyColor)
    }
}

// MARK: - Timeline List

struct TimelineListView: View {
    let items: [[String: Any]]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                timelineRow(item, isLast: i == items.count - 1)
            }
        }
    }
    
    private func dateString(_ item: [String: Any]) -> String {
        for k in ["date", "time", "timestamp", "created", "createdAt", "created_at", "updated", "updated_at"] {
            if let s = item[k] as? String { return s }
        }
        return ""
    }
    
    private func titleString(_ item: [String: Any]) -> String {
        for k in ["title", "name", "event", "label", "message"] {
            if let s = item[k] as? String { return s }
        }
        return ""
    }
    
    private func descString(_ item: [String: Any]) -> String {
        for k in ["description", "desc", "summary", "detail", "note"] {
            if let s = item[k] as? String, s != titleString(item) { return s }
        }
        return ""
    }
    
    private func statusString(_ item: [String: Any]) -> String {
        (item["status"] as? String) ?? (item["state"] as? String) ?? (item["type"] as? String) ?? ""
    }
    
    private func dotColor(_ item: [String: Any]) -> Color {
        switch statusString(item) {
        case "completed", "done", "released": return .green
        case "active", "in_progress", "current": return .blue
        case "queued", "planned", "upcoming": return Color(nsColor: DesignTokens.secondaryColor)
        case "milestone": return .orange
        case "release": return .purple
        default: return Color(nsColor: DesignTokens.secondaryColor)
        }
    }
    
    private func timelineRow(_ item: [String: Any], isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: date
            Text(dateString(item))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                .frame(width: 80, alignment: .trailing)
            
            // Center: dot + line
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor(item))
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(Color(nsColor: DesignTokens.isDark ? NSColor(white: 0.22, alpha: 1) : NSColor(white: 0.85, alpha: 1)))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 8)
            
            // Right: content
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(titleString(item))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(nsColor: DesignTokens.headingColor))
                    let st = statusString(item)
                    if !st.isEmpty {
                        Text(st)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(dotColor(item))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(dotColor(item).opacity(0.12))
                            .cornerRadius(3)
                    }
                }
                let desc = descString(item)
                if !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                }
            }
            .padding(.bottom, isLast ? 0 : 16)
            
            Spacer()
        }
    }
}

// MARK: - Shared Structured Data Renderer

/// Reusable view that renders any parsed value (from JSON or YAML) using the appropriate visualization
struct StructuredDataView: View {
    let value: Any
    
    var body: some View {
        let hint = JsonAnalyzer.analyze(value)
        switch hint {
        case .progressCards:
            if let dict = value as? [String: Any] {
                ProgressDashboardView(data: dict)
            } else if let arr = value as? [[String: Any]] {
                ProgressDashboardView(data: ["items": arr])
            }
        case .statusList:
            if let arr = value as? [[String: Any]] {
                FeatureListView(items: arr)
            } else if let dict = value as? [String: Any],
                      let (mainKey, mainArr) = JsonAnalyzer.findMainArray(in: dict) {
                DictWithMainArrayView(dict: dict, mainKey: mainKey) {
                    FeatureListView(items: mainArr)
                }
            }
        case .timeline:
            if let arr = value as? [[String: Any]] {
                TimelineListView(items: arr)
            } else if let dict = value as? [String: Any],
                      let (mainKey, mainArr) = JsonAnalyzer.findMainArray(in: dict) {
                DictWithMainArrayView(dict: dict, mainKey: mainKey) {
                    TimelineListView(items: mainArr)
                }
            }
        case .keyValuePairs:
            if let dict = value as? [String: Any] {
                KeyValueView(dict: dict)
            }
        case .arrayOfObjects:
            if let arr = value as? [[String: Any]] {
                if hasLongTextField(arr) || hasNestedObjects(arr) {
                    RichCardListView(items: arr)
                } else {
                    ArrayTableView(items: arr)
                }
            } else {
                GenericTreeView(value: value, label: "root", depth: 0)
            }
        case .arrayOfScalars:
            if let arr = value as? [Any] {
                ScalarListView(items: arr)
            }
        case .nestedObject:
            if let dict = value as? [String: Any] {
                NestedObjectView(dict: dict)
            }
        case .scalar:
            Text(String(describing: value))
                .font(.system(size: DesignTokens.bodySize))
                .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
                .textSelection(.enabled)
        }
    }
    
    private func hasLongTextField(_ arr: [[String: Any]]) -> Bool {
        arr.contains { item in
            item.values.contains { v in
                if let s = v as? String { return s.count >= 80 || s.contains("\n") }
                return false
            }
        }
    }
    
    private func hasNestedObjects(_ arr: [[String: Any]]) -> Bool {
        arr.contains { item in
            item.values.contains { v in
                v is [String: Any] || v is [[String: Any]]
            }
        }
    }
}

/// Shows scalar top-level fields as header, then renders the main array content
struct DictWithMainArrayView<Content: View>: View {
    let dict: [String: Any]
    let mainKey: String
    let content: () -> Content
    
    init(dict: [String: Any], mainKey: String, @ViewBuilder content: @escaping () -> Content) {
        self.dict = dict
        self.mainKey = mainKey
        self.content = content
    }
    
    private var headerFields: [(String, String)] {
        dict.compactMap { key, val in
            guard key != mainKey && JsonAnalyzer.isScalar(val) else { return nil }
            return (key, String(describing: val))
        }.sorted(by: { $0.0 < $1.0 })
    }
    
    private var extraSections: [(String, Any)] {
        dict.filter { key, val in
            key != mainKey && !JsonAnalyzer.isScalar(val)
        }.sorted(by: { $0.key < $1.key })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !headerFields.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(headerFields, id: \.0) { key, value in
                        HStack(spacing: 8) {
                            Text(key)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                                .frame(width: 100, alignment: .trailing)
                            Text(value)
                                .font(.system(size: 13))
                                .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            
            content()
            
            ForEach(extraSections, id: \.0) { key, value in
                VStack(alignment: .leading, spacing: 8) {
                    Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(nsColor: DesignTokens.headingColor))
                    
                    if let subDict = value as? [String: Any] {
                        KeyValueView(dict: subDict)
                    } else if let arr = value as? [[String: Any]], !arr.isEmpty {
                        StructuredDataView(value: arr)
                    } else if let arr = value as? [Any] {
                        StructuredDataView(value: arr)
                    }
                }
            }
        }
    }
}

// MARK: - Sparkline View for numeric arrays

struct SparklineView: View {
    let points: [(Double, Double)] // (x, y) pairs
    let height: CGFloat
    
    init(pairs: [[Any]], height: CGFloat = 80) {
        var pts: [(Double, Double)] = []
        for pair in pairs {
            if pair.count >= 2,
               let x = (pair[0] as? NSNumber)?.doubleValue,
               let y = (pair[1] as? NSNumber)?.doubleValue {
                pts.append((x, y))
            }
        }
        self.points = pts.sorted(by: { $0.0 < $1.0 })
        self.height = height
    }
    
    init(values: [Double], height: CGFloat = 80) {
        self.points = values.enumerated().map { (Double($0.offset), $0.element) }
        self.height = height
    }
    
    var body: some View {
        if points.count < 2 {
            Text("(insufficient data)")
                .font(.system(size: 11))
                .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
        } else {
            VStack(alignment: .leading, spacing: 4) {
                sparklineShape
                    .frame(height: height)
                    .padding(.vertical, 4)
                // Axis labels
                HStack {
                    Text(String(format: "%.1f", points.first!.0))
                    Spacer()
                    Text(String(format: "%.1f", points.last!.0))
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
            }
        }
    }
    
    private var sparklineShape: some View {
        GeometryReader { geo in
            let minX = points.map(\.0).min()!
            let maxX = points.map(\.0).max()!
            let minY = points.map(\.1).min()!
            let maxY = points.map(\.1).max()!
            let rangeX = max(maxX - minX, 0.001)
            let rangeY = max(maxY - minY, 0.001)
            
            let w = geo.size.width
            let h = geo.size.height
            
            // Fill area
            Path { path in
                for (i, pt) in points.enumerated() {
                    let x = (pt.0 - minX) / rangeX * w
                    let y = h - (pt.1 - minY) / rangeY * h
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                path.addLine(to: CGPoint(x: (points.last!.0 - minX) / rangeX * w, y: h))
                path.addLine(to: CGPoint(x: (points.first!.0 - minX) / rangeX * w, y: h))
                path.closeSubpath()
            }
            .fill(Color.blue.opacity(0.08))
            
            // Line
            Path { path in
                for (i, pt) in points.enumerated() {
                    let x = (pt.0 - minX) / rangeX * w
                    let y = h - (pt.1 - minY) / rangeY * h
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(Color.blue.opacity(0.6), lineWidth: 1.5)
            
            // Y-axis labels
            VStack {
                Text(String(format: "%.0f", maxY))
                Spacer()
                Text(String(format: "%.0f", minY))
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
        }
    }
}

// MARK: - Rich Card List (for arrays with long text fields)

struct RichCardListView: View {
    let items: [[String: Any]]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                cardView(item, index: i)
            }
        }
    }
    
    private func cardView(_ item: [String: Any], index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: short fields as pills
            let shortFields = item.filter { k, v in
                if let s = v as? String { return s.count < 80 && !s.contains("\n") }
                return JsonAnalyzer.isScalar(v)
            }.sorted(by: { $0.key < $1.key })
            
            if !shortFields.isEmpty {
                HStack(spacing: 10) {
                    ForEach(shortFields, id: \.key) { key, value in
                        HStack(spacing: 4) {
                            Text(key)
                                .font(.system(size: 10))
                                .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                            Text(scalarStr(value))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
                        }
                    }
                }
            }
            
            // Long text fields: render with basic markdown support
            let longFields = item.filter { k, v in
                if let s = v as? String { return s.count >= 80 || s.contains("\n") }
                return false
            }.sorted(by: { $0.key < $1.key })
            
            ForEach(longFields, id: \.key) { key, value in
                if let text = value as? String {
                    SimpleMarkdownText(text: text)
                }
            }
            
            // Sub-objects/arrays
            let complexFields = item.filter { k, v in
                !JsonAnalyzer.isScalar(v) && !(v is String)
            }.sorted(by: { $0.key < $1.key })
            
            ForEach(complexFields, id: \.key) { key, value in
                VStack(alignment: .leading, spacing: 4) {
                    Text(key)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(nsColor: DesignTokens.secondaryColor))
                    
                    if let pairs = value as? [[Any]], !pairs.isEmpty,
                       pairs[0].count >= 2,
                       pairs[0][0] is NSNumber, pairs[0][1] is NSNumber {
                        SparklineView(pairs: pairs, height: 60)
                    } else if let nums = value as? [NSNumber], nums.count >= 3 {
                        SparklineView(values: nums.map { $0.doubleValue }, height: 60)
                    } else if let subDict = value as? [String: Any] {
                        StructuredDataView(value: subDict)
                            .padding(.leading, 8)
                    } else {
                        GenericTreeView(value: value, label: key, depth: 0)
                            .padding(.leading, 8)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: DesignTokens.isDark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.97, alpha: 1)))
        .cornerRadius(8)
    }
    
    private func scalarStr(_ v: Any) -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return String(describing: v)
    }
}

// MARK: - Simple Markdown Text (lightweight inline renderer)

struct SimpleMarkdownText: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }
    
    private enum MdBlock {
        case heading(String, Int)
        case table([[String]])
        case text(String)
    }
    
    private var blocks: [MdBlock] {
        var result: [MdBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Heading
            if trimmed.hasPrefix("##") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let title = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty { result.append(.heading(title, level)) }
                i += 1
                continue
            }
            
            // Table detection
            if trimmed.contains("|") && i + 1 < lines.count {
                let nextTrimmed = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if nextTrimmed.contains("---") && nextTrimmed.contains("|") {
                    var rows: [[String]] = []
                    rows.append(parseTableRow(trimmed))
                    var j = i + 2 // skip separator
                    while j < lines.count {
                        let rowLine = lines[j].trimmingCharacters(in: .whitespaces)
                        if rowLine.contains("|") && !rowLine.isEmpty {
                            rows.append(parseTableRow(rowLine))
                            j += 1
                        } else { break }
                    }
                    result.append(.table(rows))
                    i = j
                    continue
                }
            }
            
            // Plain text
            if !trimmed.isEmpty {
                result.append(.text(trimmed))
            }
            i += 1
        }
        return result
    }
    
    private func parseTableRow(_ line: String) -> [String] {
        line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    @ViewBuilder
    private func blockView(_ block: MdBlock) -> some View {
        switch block {
        case .heading(let title, let level):
            Text(title)
                .font(.system(size: level <= 2 ? 14 : 12, weight: .medium))
                .foregroundColor(Color(nsColor: DesignTokens.headingColor))
                .padding(.top, 6)
        case .table(let rows):
            tableView(rows)
        case .text(let line):
            Text(line)
                .font(.system(size: 12))
                .foregroundColor(Color(nsColor: DesignTokens.bodyColor))
                .textSelection(.enabled)
        }
    }
    
    private func tableView(_ rows: [[String]]) -> some View {
        let maxCols = rows.map(\.count).max() ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { ri, row in
                HStack(spacing: 0) {
                    ForEach(0..<maxCols, id: \.self) { ci in
                        let cell = ci < row.count ? row[ci] : ""
                        Text(cell)
                            .font(.system(size: ri == 0 ? 10 : 11, weight: ri == 0 ? .medium : .regular, design: .monospaced))
                            .foregroundColor(Color(nsColor: ri == 0 ? DesignTokens.secondaryColor : DesignTokens.bodyColor))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                    }
                }
                .background(Color(nsColor: ri == 0 ? DesignTokens.tableHeaderBackground : (ri % 2 == 0 ? DesignTokens.tableEvenRow : DesignTokens.tableOddRow)))
            }
        }
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(nsColor: DesignTokens.tableBorder), lineWidth: 0.5)
        )
    }
}

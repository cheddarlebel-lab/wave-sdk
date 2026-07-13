import Foundation

/// SICM internal reason -> member-facing message. Carried forward verbatim from the
/// contract denial table (contract/conformance/denial-mapping.json) and the app's
/// bridge_v3 friendly_reason().
public enum DenialMapping {
    public static let table: [(sicm: String, friendly: String)] = [
        ("Granted by provider cache", "Access Granted"),
        ("Client not found", "Member not found"),
        ("Blocked by schedule", "Outside access hours"),
        ("Maximum active signins", "Maximum active sign-ins reached"),
        ("Checkins limitation", "Daily check-in limit reached"),
        ("Blocked by restriction", "Membership restriction"),
        ("Blocked by client alert", "Account alert"),
        ("Over account balance", "Outstanding balance"),
        ("Liability release", "Liability release required"),
        ("Scheduled visit", "No booking found"),
        ("No member picture", "Photo required"),
        ("Provider not found", "System error - provider unavailable"),
        ("Inactive", "Membership inactive"),
        ("Expired", "Membership expired"),
    ]

    /// Map a raw reason to a friendly one. Substring match (SICM emits verbose lines
    /// like "Blocked by provider : 604 : Client not found"); falls back to the raw
    /// text, or a generic message when empty.
    public static func friendly(_ raw: String?) -> String {
        guard let raw = raw, !raw.isEmpty else { return "Access denied" }
        // Strip a leading "[mock] " tag if present.
        let cleaned = raw.hasPrefix("[mock] ") ? String(raw.dropFirst(7)) : raw
        for entry in table where cleaned.range(of: entry.sicm, options: .caseInsensitive) != nil {
            return entry.friendly
        }
        // Already-friendly value passes through.
        for entry in table where cleaned.caseInsensitiveCompare(entry.friendly) == .orderedSame {
            return entry.friendly
        }
        return cleaned
    }
}

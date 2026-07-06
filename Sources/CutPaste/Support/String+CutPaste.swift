import Foundation

extension String {
    func clipped(to limit: Int) -> String {
        guard count > limit else { return self }
        return String(prefix(max(0, limit - 1))) + "…"
    }

    var trimmedForDisplay: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
    }
}

import Foundation

struct ShortcutCard: Identifiable, Codable {
    var id = UUID()
    var title: String
    var keys: String
    var description: String
    var category: String = "Allgemein"
}

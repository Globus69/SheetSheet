import Foundation
import Observation

@Observable
final class CardStore {
    var cards: [ShortcutCard] = [] {
        didSet { if !isLoading { save() } }
    }
    private var isLoading = false

    private let storageURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("SheetSheet", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cards.json")
    }()

    init() {
        load()
    }

    func delete(_ card: ShortcutCard) {
        cards.removeAll { $0.id == card.id }
    }

    func move(from source: IndexSet, to destination: Int) {
        cards.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Persistence

    private func load() {
        isLoading = true
        defer { isLoading = false }
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ShortcutCard].self, from: data)
        else {
            cards = CardStore.defaultCards
            return
        }
        cards = decoded
    }

    // MARK: - Default cards (Apple macOS standard shortcuts)

    static let defaultCards: [ShortcutCard] = [
        // System
        ShortcutCard(title: "Spotlight", keys: "⌘Space", description: "Spotlight-Suche", category: "System"),
        ShortcutCard(title: "Sperren", keys: "⌃⌘Q", description: "Bildschirm sperren", category: "System"),
        ShortcutCard(title: "Ausschalten", keys: "⌃⏏", description: "Dialog: Neustart/Ausschalten", category: "System"),
        ShortcutCard(title: "Screenshot", keys: "⌘⇧3", description: "Vollbild", category: "System"),
        ShortcutCard(title: "Screenshot Auswahl", keys: "⌘⇧4", description: "Bereich auswählen", category: "System"),
        ShortcutCard(title: "Screenshot Fenster", keys: "⌘⇧4 Space", description: "Fenster wählen", category: "System"),
        ShortcutCard(title: "Screenshot-Tool", keys: "⌘⇧5", description: "Tool & Aufnahme", category: "System"),
        ShortcutCard(title: "Diktat", keys: "Fn Fn", description: "Diktierfunktion", category: "System"),
        ShortcutCard(title: "Emoji & Symbole", keys: "⌃⌘Space", description: "Zeichenübersicht", category: "System"),

        // Fenster & Apps
        ShortcutCard(title: "App wechseln", keys: "⌘Tab", description: "Zwischen Apps", category: "Fenster & Apps"),
        ShortcutCard(title: "Fenster wechseln", keys: "⌘`", description: "Selbe App", category: "Fenster & Apps"),
        ShortcutCard(title: "App beenden", keys: "⌘Q", description: "", category: "Fenster & Apps"),
        ShortcutCard(title: "Fenster schließen", keys: "⌘W", description: "", category: "Fenster & Apps"),
        ShortcutCard(title: "Ausblenden", keys: "⌘H", description: "App ausblenden", category: "Fenster & Apps"),
        ShortcutCard(title: "Alle ausblenden", keys: "⌘⌥H", description: "Andere ausblenden", category: "Fenster & Apps"),
        ShortcutCard(title: "Minimieren", keys: "⌘M", description: "Ins Dock", category: "Fenster & Apps"),
        ShortcutCard(title: "Vollbild", keys: "⌃⌘F", description: "Umschalten", category: "Fenster & Apps"),
        ShortcutCard(title: "Mission Control", keys: "⌃↑", description: "Alle Fenster", category: "Fenster & Apps"),
        ShortcutCard(title: "App-Fenster", keys: "⌃↓", description: "Aktuelle App", category: "Fenster & Apps"),
        ShortcutCard(title: "Schreibtisch", keys: "⌘F3", description: "Alle wegräumen", category: "Fenster & Apps"),

        // Bearbeiten
        ShortcutCard(title: "Ausschneiden", keys: "⌘X", description: "", category: "Bearbeiten"),
        ShortcutCard(title: "Kopieren", keys: "⌘C", description: "", category: "Bearbeiten"),
        ShortcutCard(title: "Einsetzen", keys: "⌘V", description: "", category: "Bearbeiten"),
        ShortcutCard(title: "Einsetzen & Stil", keys: "⌘⌥⇧V", description: "Ohne Formatierung", category: "Bearbeiten"),
        ShortcutCard(title: "Widerrufen", keys: "⌘Z", description: "", category: "Bearbeiten"),
        ShortcutCard(title: "Wiederholen", keys: "⌘⇧Z", description: "", category: "Bearbeiten"),
        ShortcutCard(title: "Alles auswählen", keys: "⌘A", description: "", category: "Bearbeiten"),
        ShortcutCard(title: "Suchen", keys: "⌘F", description: "", category: "Bearbeiten"),
        ShortcutCard(title: "Weitersuchen", keys: "⌘G", description: "", category: "Bearbeiten"),
        ShortcutCard(title: "Rückwärts suchen", keys: "⌘⇧G", description: "", category: "Bearbeiten"),
        ShortcutCard(title: "Ersetzen", keys: "⌘⌥F", description: "", category: "Bearbeiten"),
        ShortcutCard(title: "Schrift fett", keys: "⌘B", description: "", category: "Bearbeiten"),
        ShortcutCard(title: "Schrift kursiv", keys: "⌘I", description: "", category: "Bearbeiten"),
        ShortcutCard(title: "Schrift unterstrichen", keys: "⌘U", description: "", category: "Bearbeiten"),

        // Dokument
        ShortcutCard(title: "Neu", keys: "⌘N", description: "", category: "Dokument"),
        ShortcutCard(title: "Öffnen", keys: "⌘O", description: "", category: "Dokument"),
        ShortcutCard(title: "Sichern", keys: "⌘S", description: "", category: "Dokument"),
        ShortcutCard(title: "Sichern unter", keys: "⌘⇧S", description: "", category: "Dokument"),
        ShortcutCard(title: "Drucken", keys: "⌘P", description: "", category: "Dokument"),
        ShortcutCard(title: "Papierkorb leeren", keys: "⌘⇧⌫", description: "Sofort leeren", category: "Dokument"),

        // Finder
        ShortcutCard(title: "Neues Fenster", keys: "⌘N", description: "", category: "Finder"),
        ShortcutCard(title: "Neuer Tab", keys: "⌘T", description: "", category: "Finder"),
        ShortcutCard(title: "Info", keys: "⌘I", description: "Objekt-Info", category: "Finder"),
        ShortcutCard(title: "Schnellübersicht", keys: "Space", description: "Quick Look", category: "Finder"),
        ShortcutCard(title: "Übergeordnet", keys: "⌘↑", description: "Ordner öffnen", category: "Finder"),
        ShortcutCard(title: "Öffnen", keys: "⌘↓", description: "", category: "Finder"),
        ShortcutCard(title: "Neuer Ordner", keys: "⌘⇧N", description: "", category: "Finder"),
        ShortcutCard(title: "In Papierkorb", keys: "⌘⌫", description: "", category: "Finder"),
        ShortcutCard(title: "Umbenennen", keys: "Return", description: "", category: "Finder"),
        ShortcutCard(title: "Gehe zu Ordner", keys: "⌘⇧G", description: "Pfad eingeben", category: "Finder"),
        ShortcutCard(title: "AirDrop", keys: "⌘⇧R", description: "", category: "Finder"),
        ShortcutCard(title: "Mit Server verbinden", keys: "⌘K", description: "", category: "Finder"),
        ShortcutCard(title: "Versteckte Dateien", keys: "⌘⇧.", description: "Ein-/ausblenden", category: "Finder"),
        ShortcutCard(title: "Symbolansicht", keys: "⌘1", description: "", category: "Finder"),
        ShortcutCard(title: "Listenansicht", keys: "⌘2", description: "", category: "Finder"),
        ShortcutCard(title: "Spaltenansicht", keys: "⌘3", description: "", category: "Finder"),
        ShortcutCard(title: "Galerieansicht", keys: "⌘4", description: "", category: "Finder"),
    ]

    private func save() {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}

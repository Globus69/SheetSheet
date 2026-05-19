import SwiftUI

private let customCategory = "Eigene Kürzel"

struct OverlayView: View {
    @State var cardStore: CardStore
    @State private var editMode = false
    @State private var newTitle = ""
    @State private var newKeys = ""
    @State private var newDescription = ""
    @State private var newCategory = ""

    // Fixed order: first 5 predefined categories, slot 6 = custom
    private let predefinedOrder = ["System", "Fenster & Apps", "Bearbeiten", "Dokument", "Finder"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if editMode {
                editList
                addCardForm
            } else {
                cheatSheet
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("SheetSheet")
                .font(.headline)
            Spacer()
            Button(editMode ? "Fertig" : "Bearbeiten") {
                withAnimation { editMode.toggle() }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Cheat sheet (3 × 2, slot 6 = custom)

    private var cheatSheet: some View {
        GeometryReader { geo in
            let cols = 3
            let rows = 2
            let hPad: CGFloat = 12
            let vPad: CGFloat = 12
            let gap: CGFloat = 10
            let colW = (geo.size.width  - hPad * 2 - gap * CGFloat(cols - 1)) / CGFloat(cols)
            let rowH = (geo.size.height - vPad * 2 - gap * CGFloat(rows - 1)) / CGFloat(rows)

            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<cols, id: \.self) { c in
                            let idx = r * cols + c
                            Group {
                                if idx < predefinedOrder.count {
                                    let cat = predefinedOrder[idx]
                                    CategoryBox(
                                        category: cat,
                                        cards: cardStore.cards.filter { $0.category == cat }
                                    )
                                } else {
                                    // Bottom-right: custom slot
                                    CustomCategoryBox(
                                        cards: Binding(
                                            get: { cardStore.cards.filter { $0.category == customCategory } },
                                            set: { _ in }
                                        ),
                                        onAdd: { title, keys, desc in
                                            cardStore.cards.append(ShortcutCard(
                                                title: title, keys: keys,
                                                description: desc, category: customCategory
                                            ))
                                        },
                                        onDelete: { card in cardStore.delete(card) }
                                    )
                                }
                            }
                            .frame(width: colW, height: rowH)
                        }
                    }
                }
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
        }
    }

    // MARK: - Edit list

    private var editList: some View {
        List {
            ForEach($cardStore.cards) { $card in
                EditableCardRow(card: $card) { cardStore.delete(card) }
            }
            .onMove { cardStore.move(from: $0, to: $1) }
            .onDelete { cardStore.cards.remove(atOffsets: $0) }
        }
        .listStyle(.plain)
    }

    // MARK: - Add card form (edit mode)

    private var addCardForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(spacing: 8) {
                TextField("Titel", text: $newTitle).textFieldStyle(.roundedBorder)
                TextField("Tasten  (z.B. ⌘⇧P)", text: $newKeys).textFieldStyle(.roundedBorder).frame(width: 150)
                TextField("Kategorie", text: $newCategory).textFieldStyle(.roundedBorder).frame(width: 130)
            }
            HStack(spacing: 8) {
                TextField("Beschreibung (optional)", text: $newDescription).textFieldStyle(.roundedBorder)
                Spacer()
                Button("Hinzufügen") { addCard() }
                    .disabled(newTitle.isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(12)
    }

    private func addCard() {
        guard !newTitle.isEmpty else { return }
        cardStore.cards.append(ShortcutCard(
            title: newTitle, keys: newKeys,
            description: newDescription,
            category: newCategory.isEmpty ? "Allgemein" : newCategory
        ))
        newTitle = ""; newKeys = ""; newDescription = ""; newCategory = ""
    }
}

// MARK: - Custom category box (inline +/−)

private struct CustomCategoryBox: View {
    let cards: Binding<[ShortcutCard]>
    let onAdd: (String, String, String) -> Void
    let onDelete: (ShortcutCard) -> Void

    @State private var newTitle = ""
    @State private var newKeys = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row with + button
            HStack {
                Text(customCategory)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Button {
                    titleFocused = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.borderless)
                .help("Neuen Eintrag hinzufügen")
            }

            Divider()

            // Existing entries with − button
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(cards.wrappedValue) { card in
                        HStack(spacing: 6) {
                            KeyBadge(keys: card.keys)
                            Text(card.title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Button {
                                onDelete(card)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            // Inline add form
            VStack(spacing: 4) {
                Divider()
                HStack(spacing: 6) {
                    TextField("Titel", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .focused($titleFocused)
                        .onSubmit { commitAdd() }
                    KeyCaptureField(text: $newKeys, placeholder: "⌘…")
                        .frame(width: 80, height: 22)
                    Button {
                        commitAdd()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newTitle.isEmpty)
                }
                if titleFocused || !newKeys.isEmpty || !newTitle.isEmpty {
                    Text("Fn loslassen: Fenster bleibt offen  ·  Esc: Schließen")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func commitAdd() {
        guard !newTitle.isEmpty else { return }
        onAdd(newTitle, newKeys, "")
        newTitle = ""
        newKeys = ""
    }
}

// MARK: - Category box (predefined, read-only)

private struct CategoryBox: View {
    let category: String
    let cards: [ShortcutCard]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            Divider()

            let half = Int(ceil(Double(cards.count) / 2.0))
            let left  = Array(cards.prefix(half))
            let right = Array(cards.dropFirst(half))

            GeometryReader { geo in
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(left)  { CardRow(card: $0) }
                    }
                    .frame(width: (geo.size.width - 8) / 2, alignment: .leading)

                    Divider()

                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(right) { CardRow(card: $0) }
                    }
                    .frame(width: (geo.size.width - 8) / 2, alignment: .leading)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Card row

private struct CardRow: View {
    let card: ShortcutCard
    var body: some View {
        HStack(spacing: 6) {
            KeyBadge(keys: card.keys)
            VStack(alignment: .leading, spacing: 0) {
                Text(card.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                if !card.description.isEmpty {
                    Text(card.description)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct KeyBadge: View {
    let keys: String
    var body: some View {
        Text(keys.isEmpty ? "–" : keys)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.18), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(minWidth: 64, alignment: .center)
    }
}

// MARK: - Editable row (edit mode)

private struct EditableCardRow: View {
    @Binding var card: ShortcutCard
    let onDelete: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TextField("Titel", text: $card.title).textFieldStyle(.roundedBorder)
                    TextField("Tasten", text: $card.keys).textFieldStyle(.roundedBorder).frame(width: 110)
                    TextField("Kategorie", text: $card.category).textFieldStyle(.roundedBorder).frame(width: 110)
                }
                TextField("Beschreibung", text: $card.description).textFieldStyle(.roundedBorder)
            }
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless).foregroundStyle(.red)
        }
        .padding(.vertical, 3)
    }
}

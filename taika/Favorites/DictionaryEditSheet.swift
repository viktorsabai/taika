//
//  DictionaryEditSheet.swift
//  taika
//
//  Inline edit sheet for personal dictionary phrases (RU / Thai / translit).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DictionaryEditTarget: Identifiable, Equatable {
    let card: FDCardDTO

    var id: String {
        let sid = card.sourceId.trimmingCharacters(in: .whitespacesAndNewlines)
        return sid.isEmpty ? card.id : sid
    }
}

struct DictionaryEditSheet: View {
    let card: FDCardDTO
    let onDismiss: () -> Void

    @ObservedObject private var favorites = FavoriteManager.shared
    @State private var ru = ""
    @State private var thai = ""
    @State private var translit = ""
    @State private var showDuplicateError = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case ru, thai, translit
    }

    private var cardId: String {
        DictionaryEditTarget(card: card).id
    }

    private var trimmedThai: String {
        thai.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedTranslit: String {
        translit.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedRU: String {
        ru.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasDuplicateThai: Bool {
        guard !trimmedThai.isEmpty else { return false }
        return favorites.hasSmartSpeakerDictionaryEntry(thai: trimmedThai, excludingId: cardId)
    }

    private var hasChanges: Bool {
        trimmedRU != card.title.trimmingCharacters(in: .whitespacesAndNewlines)
            || trimmedThai != card.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            || trimmedTranslit != card.meta.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedThai.isEmpty
            && !trimmedTranslit.isEmpty
            && !hasDuplicateThai
            && hasChanges
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    editField(
                        title: "Русский",
                        placeholder: "Что ты хотел сказать",
                        text: $ru,
                        field: .ru,
                        axis: .vertical
                    )
                    editField(
                        title: "Тайский",
                        placeholder: "Тайская фраза",
                        text: $thai,
                        field: .thai
                    )
                    editField(
                        title: "Транслит",
                        placeholder: "Произношение",
                        text: $translit,
                        field: .translit,
                        axis: .vertical
                    )

                    if hasDuplicateThai || showDuplicateError {
                        Text("Такая тайская фраза уже есть в словаре")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(CD.ColorToken.background.ignoresSafeArea())
            .navigationTitle("Изменить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear {
            ru = card.title
            thai = card.subtitle
            translit = card.meta
        }
        .onChange(of: thai) { _, _ in
            showDuplicateError = false
        }
    }

    @ViewBuilder
    private func editField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CD.ColorToken.textSecondary)
            TextField(placeholder, text: text, axis: axis)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(CD.ColorToken.text)
                .focused($focusedField, equals: field)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(CD.ColorToken.card.opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PD.ColorToken.stroke.opacity(0.75), lineWidth: 1)
                )
        }
    }

    private func save() {
        guard canSave else { return }
        let ok = favorites.updateSmartSpeakerDictionaryEntry(
            id: cardId,
            ru: trimmedRU,
            thai: trimmedThai,
            phonetic: trimmedTranslit
        )
        if ok {
#if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
            onDismiss()
        } else {
            showDuplicateError = true
#if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
#endif
        }
    }
}

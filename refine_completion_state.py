from pathlib import Path

appds = Path('taika/Theme/AppDS.swift')
text = appds.read_text()

old_props = '''    /// На итоге курса/трека игры прячем — один нативный хук «закрепить голосом».
    public var showGameReinforce: Bool
    public var lessonDurationText: String? = nil
'''
new_props = '''    /// На completion screen показываем компактные game chips, если true.
    public var showGameReinforce: Bool
    /// Доступность PRO-режимов для free/PRO state rendering.
    public var isProUser: Bool
    /// Штатный callback для locked game; overlay должен остаться в исходном context.
    public var onLockedGame: ((GameModeType) -> Void)?
    public var lessonDurationText: String? = nil
'''
if old_props not in text:
    raise SystemExit('props marker not found')
text = text.replace(old_props, new_props, 1)

old_init = '''        onSelectGameMode: ((GameModeType) -> Void)? = nil,
        showGameReinforce: Bool = true,
        lessonDurationText: String? = nil,
'''
new_init = '''        onSelectGameMode: ((GameModeType) -> Void)? = nil,
        showGameReinforce: Bool = true,
        isProUser: Bool = true,
        onLockedGame: ((GameModeType) -> Void)? = nil,
        lessonDurationText: String? = nil,
'''
if old_init not in text:
    raise SystemExit('init args marker not found')
text = text.replace(old_init, new_init, 1)

old_assign = '''        self.onSelectGameMode = onSelectGameMode
        self.showGameReinforce = showGameReinforce
        self.lessonDurationText = lessonDurationText
'''
new_assign = '''        self.onSelectGameMode = onSelectGameMode
        self.showGameReinforce = showGameReinforce
        self.isProUser = isProUser
        self.onLockedGame = onLockedGame
        self.lessonDurationText = lessonDurationText
'''
if old_assign not in text:
    raise SystemExit('init assignment marker not found')
text = text.replace(old_assign, new_assign, 1)

old_footer_call = '''                                    footerBlock()
                                        .padding(.top, 4)
'''
new_footer_call = '''                                    approvedCompletionFooter()
                                        .padding(.top, 4)
'''
if old_footer_call not in text:
    raise SystemExit('footer call marker not found')
text = text.replace(old_footer_call, new_footer_call, 1)

marker = '''    @ViewBuilder
    private func footerBlock() -> some View {
'''
if marker not in text:
    raise SystemExit('footer marker not found')

new_helpers = r'''    private var approvedIsFinalState: Bool {
        kind == .course || kind == .catalogEnd
    }

    private var approvedPrimaryCaption: String {
        if approvedIsFinalState { return "Кун Кру уже приготовила следующий маршрут" }
        let value = primaryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("дальше:") {
            return value.replacingOccurrences(of: "Дальше:", with: "Следующий урок:")
        }
        return value
    }

    private func approvedMetaValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @ViewBuilder
    private func approvedCompletionMetaRibbon() -> some View {
        let duration = approvedMetaValue(lessonDurationText)
        let progress = approvedMetaValue(overallProgressText)
        HStack(spacing: 9) {
            Label(approvedIsFinalState ? "курс завершён" : "урок завершён", systemImage: approvedIsFinalState ? "checkmark.seal" : "sparkles")
                .lineLimit(1)
            if let progress {
                Text("•")
                Text(progress)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            if let duration {
                Text("•")
                Label(duration, systemImage: "clock")
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
        .padding(.horizontal, 14)
        .frame(minHeight: 38)
        .background(Capsule(style: .continuous).fill(CD.ColorToken.card.opacity(0.48)))
        .overlay(Capsule(style: .continuous).stroke(Theme.Strokes.strokeSubtle, lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func approvedCompletionFooter() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onPrimary()
            }) {
                Text(primaryTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
                    .overlay(Capsule(style: .continuous).fill(LinearGradient(colors: [Color.white.opacity(0.14), .clear], startPoint: .top, endPoint: .center)).blendMode(.plusLighter))
                    .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))

            Text(approvedPrimaryCaption)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .center)

            if let onSpeakerPractice {
                VStack(alignment: .leading, spacing: 8) {
                    Text(approvedIsFinalState ? "Закрепь результат" : "Кун Кру советует")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        onSpeakerPractice()
                    }) {
                        HStack(spacing: 11) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            Text(speakerPracticeTitle == "К каталогу курсов" ? "Попробовать в Спикере" : speakerPracticeTitle)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(CD.ColorToken.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Capsule(style: .continuous).fill(CD.ColorToken.card.opacity(0.42)))
                        .overlay(Capsule(style: .continuous).stroke(ThemeManager.shared.currentAccentFill.opacity(0.82), lineWidth: 1.2))
                    }
                    .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.98))
                    Text("Скажи фразы вслух — я помогу услышать тоны")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.88))
                        .lineLimit(2)
                }
                .padding(.top, 4)
            }

            if showGameReinforce, let onSelectGameMode {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Или закрепи в игре")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                    HStack(spacing: 7) {
                        ForEach(GameModeType.modesLessonAndPark, id: \.self) { mode in
                            approvedGameChip(mode, selected: selectedGameMode == mode, onSelect: onSelectGameMode)
                        }
                    }
                }
            }

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onClose()
            }) {
                Text(approvedIsFinalState ? "Вернуться к курсам" : "Остаться в курсе")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
        }
    }

    @ViewBuilder
    private func approvedGameChip(_ mode: GameModeType, selected: Bool, onSelect: @escaping (GameModeType) -> Void) -> some View {
        let locked = mode.isPro && !isProUser
        Button(action: {
            UIImpactFeedbackGenerator(style: locked ? .light : .soft).impactOccurred()
            if locked {
                onLockedGame?(mode)
            } else {
                onSelect(mode)
                if mode == selectedGameMode { onSecondary() }
            }
        }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Image(systemName: approvedGameIcon(mode))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(locked ? CD.ColorToken.textSecondary : ThemeManager.shared.currentAccentFill)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.8))
                    }
                }
                Text(approvedGameTitle(mode))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(locked ? CD.ColorToken.textSecondary : CD.ColorToken.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(approvedGameHint(mode))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(selected && !locked ? ThemeManager.shared.currentAccentFill.opacity(0.16) : CD.ColorToken.card.opacity(0.48)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selected && !locked ? ThemeManager.shared.currentAccentFill.opacity(0.85) : Theme.Strokes.strokeSubtle, lineWidth: selected && !locked ? 1.2 : 1))
        }
        .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.98))
    }

    private func approvedGameTitle(_ mode: GameModeType) -> String {
        switch mode {
        case .match: return "Чап-кху"
        case .recall: return "Там-кхам"
        case .audioRecall: return "Фанг-лыак"
        case .grandDialogue: return "Диалог"
        }
    }

    private func approvedGameHint(_ mode: GameModeType) -> String {
        switch mode {
        case .match: return "найди пару"
        case .recall: return "собери слово"
        case .audioRecall: return "послушай"
        case .grandDialogue: return "поговори"
        }
    }

    private func approvedGameIcon(_ mode: GameModeType) -> String {
        switch mode {
        case .match: return "square.grid.2x2.fill"
        case .recall: return "textformat.abc"
        case .audioRecall: return "speaker.wave.2.fill"
        case .grandDialogue: return "bubble.left.and.bubble.right.fill"
        }
    }

'''
text = text.replace(marker, new_helpers + marker, 1)
appds.write_text(text)

step = Path('taika/Course/Lessons/Steps/StepView.swift')
s = step.read_text()
s = s.replace('''            case .nextCourse, .end:
                return "Закрепить голосом"
''', '''            case .nextCourse:
                return "Выбрать следующий курс"
            case .end:
                return "Посмотреть курсы"
''', 1)
s = s.replace('''            case .nextCourse:
                return "К следующему курсу"
            case .nextLesson:
                return "Практика в Спикере"
            case .end:
                return "К каталогу курсов"
''', '''            case .nextCourse, .nextLesson, .end:
                return "Попробовать в Спикере"
''', 1)
s = s.replace('''                case .nextCourse:
                    openSpeakerPractice(courseId: cid, lessonId: resolvedLessonId)
                }
''', '''                case .nextCourse(let nextCourseId, let firstLessonId):
                    navigateToNextCourse(courseId: nextCourseId, lessonId: firstLessonId)
                }
''', 1)
s = s.replace('''                case .nextCourse(let nextCourseId, let firstLessonId):
                    navigateToNextCourse(courseId: nextCourseId, lessonId: firstLessonId)
                case .end:
                    withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                    scheduleAuthSoftWallIfNeeded()
                    nav.openCourseCatalog()
''', '''                case .nextCourse:
                    openSpeakerPractice(courseId: cid, lessonId: resolvedLessonId)
                case .end:
                    openSpeakerPractice(courseId: cid, lessonId: resolvedLessonId)
''', 1)
s = s.replace('''            selectedGameMode: isCourseMoment ? nil : summaryGameMode,
            onSelectGameMode: isCourseMoment ? nil : { mode in
''', '''            selectedGameMode: summaryGameMode,
            onSelectGameMode: { mode in
''', 1)
s = s.replace('''            showGameReinforce: !isCourseMoment,
            lessonDurationText: lessonDurationTextValue(),
''', '''            showGameReinforce: true,
            isProUser: ProManager.shared.isPro,
            onLockedGame: { _ in
                OverlayPresenter.shared.presentPro(reason: .games, courseId: cid)
            },
            lessonDurationText: lessonDurationTextValue(),
''', 1)
step.write_text(s)

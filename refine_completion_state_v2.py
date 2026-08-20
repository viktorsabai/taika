from pathlib import Path

appds = Path('taika/Theme/AppDS.swift')
text = appds.read_text()

# Add an explicit next-step caption and direct game-open callback while retaining defaults.
text = text.replace('''    public var onLockedGame: ((GameModeType) -> Void)?
    public var lessonDurationText: String? = nil
''', '''    public var onLockedGame: ((GameModeType) -> Void)?
    public var onOpenGame: ((GameModeType) -> Void)?
    public var primaryCaption: String?
    public var lessonDurationText: String? = nil
''', 1)
text = text.replace('''        onLockedGame: ((GameModeType) -> Void)? = nil,
        lessonDurationText: String? = nil,
''', '''        onLockedGame: ((GameModeType) -> Void)? = nil,
        onOpenGame: ((GameModeType) -> Void)? = nil,
        primaryCaption: String? = nil,
        lessonDurationText: String? = nil,
''', 1)
text = text.replace('''        self.onLockedGame = onLockedGame
        self.lessonDurationText = lessonDurationText
''', '''        self.onLockedGame = onLockedGame
        self.onOpenGame = onOpenGame
        self.primaryCaption = primaryCaption
        self.lessonDurationText = lessonDurationText
''', 1)

# Let the caption use the caller's real destination description.
old_caption = '''    private var approvedPrimaryCaption: String {
        if approvedIsFinalState { return "Кун Кру уже приготовила следующий маршрут" }
        let value = primaryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("дальше:") {
            return value.replacingOccurrences(of: "Дальше:", with: "Следующий урок:")
        }
        return value
    }
'''
new_caption = '''    private var approvedPrimaryCaption: String {
        if let primaryCaption, !primaryCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return primaryCaption
        }
        if approvedIsFinalState { return "Кун Кру уже приготовила следующий маршрут" }
        let value = primaryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("дальше:") {
            return value.replacingOccurrences(of: "Дальше:", with: "Следующий урок:")
        }
        return value
    }
'''
if old_caption in text:
    text = text.replace(old_caption, new_caption, 1)

# Replace body of LessonSummaryOverlay only.
struct_start = text.index('public struct LessonSummaryOverlay')
body_start = text.index('    public var body: some View {', struct_start)
body_end = text.index('\n}\n\n// MARK: - HomeTask Summary Overlay', body_start)
new_body = r'''    public var body: some View {
        GeometryReader { proxy in
            let panelW = min(max(proxy.size.width - 32, 280), 420)
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()

                TaikaRootVerticalScroll {
                    ProStyleModalPanel(maxWidth: panelW) {
                        ZStack(alignment: .topTrailing) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("taikA")
                                        .font(.taikaLogo(16))
                                        .foregroundStyle(CD.ColorToken.text)
                                    Spacer(minLength: 0)
                                }

                                ZStack {
                                    Circle()
                                        .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 2.2)
                                        .frame(width: 72, height: 72)
                                        .shadow(color: ThemeManager.shared.currentAccentFill.opacity(0.55), radius: 14)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 31, weight: .bold))
                                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                }
                                .frame(maxWidth: .infinity)
                                .scaleEffect(animateIntro ? 1 : 0.92)
                                .opacity(animateIntro ? 1 : 0)

                                VStack(alignment: .center, spacing: 7) {
                                    Text(title)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(CD.ColorToken.text)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                    Text(subtitle)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundStyle(CD.ColorToken.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .minimumScaleFactor(0.82)
                                }
                                .opacity(animateIntro ? 1 : 0)
                                .offset(y: animateIntro ? 0 : 8)

                                approvedCompletionMetaRibbon()
                                    .opacity(animateIntro ? 1 : 0)
                                    .offset(y: animateIntro ? 0 : 8)

                                approvedCompletionFooter()
                                    .opacity(animateCTA ? 1 : 0)
                                    .offset(y: animateCTA ? 0 : 12)

                                if let hacksAccessory {
                                    hacksAccessory
                                        .frame(maxWidth: .infinity)
                                        .hidden()
                                        .frame(height: 0)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                            .padding(.horizontal, 4)

                            Button(action: { onClose() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(CD.ColorToken.textSecondary)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color.white.opacity(0.08)))
                                    .overlay(Circle().stroke(Theme.Strokes.strokeSubtle, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear { startIntroAnimationIfNeeded() }
            .onChange(of: title) { _, _ in
                animateIntro = false
                animateReward = false
                animateCTA = false
                startIntroAnimationIfNeeded()
            }
        }
    }
'''
text = text[:body_start] + new_body + text[body_end:]

# Game chip opens its mode in one tap when available.
old_game = '''            if locked {
                onLockedGame?(mode)
            } else {
                onSelect(mode)
                if mode == selectedGameMode { onSecondary() }
            }
'''
new_game = '''            if locked {
                onLockedGame?(mode)
            } else {
                onSelect(mode)
                if let onOpenGame {
                    onOpenGame(mode)
                } else if mode == selectedGameMode {
                    onSecondary()
                }
            }
'''
if old_game in text:
    text = text.replace(old_game, new_game, 1)
appds.write_text(text)

step = Path('taika/Course/Lessons/Steps/StepView.swift')
s = step.read_text()
# Primary final course actions must not route to Speaker.
s = s.replace('''                case .end:
                    openSpeakerPractice(courseId: cid, lessonId: resolvedLessonId)
                case .nextLesson:
''', '''                case .end:
                    withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                    scheduleAuthSoftWallIfNeeded()
                    nav.openCourseCatalog()
                case .nextLesson:
''', 1)
# Add next-step caption before the LessonSummaryOverlay call.
needle = '''        let speakerIcon: String = {
            switch advance {
            case .nextCourse, .end: return "arrow.right"
            case .nextLesson: return "mic.fill"
            }
        }()
'''
replacement = '''        let speakerIcon: String = {
            switch advance {
            case .nextCourse, .end, .nextLesson: return "mic.fill"
            }
        }()
        let primaryCaption: String = {
            switch advance {
            case .nextLesson(_, let nextId):
                let nextTitle = LessonsData.shared.lessonTitle(for: nextId) ?? "следующий урок"
                return "Следующий урок: «\\(nextTitle)»"
            case .nextCourse:
                return "Кун Кру советует продолжить маршрут"
            case .end:
                return "Кун Кру уже приготовила другие курсы"
            }
        }()
'''
if needle in s:
    s = s.replace(needle, replacement, 1)
# Pass direct game route callback and caption.
needle2 = '''            onLockedGame: { _ in
                OverlayPresenter.shared.presentPro(reason: .games, courseId: cid)
            },
            lessonDurationText: lessonDurationTextValue(),
'''
replacement2 = '''            onLockedGame: { _ in
                OverlayPresenter.shared.presentPro(reason: .games, courseId: cid)
            },
            onOpenGame: { mode in
                withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                scheduleAuthSoftWallIfNeeded()
                nav.go(.game(courseId: cid, lessonId: resolvedLessonId, gameType: mode.rawValue))
            },
            primaryCaption: primaryCaption,
            lessonDurationText: lessonDurationTextValue(),
'''
if needle2 in s:
    s = s.replace(needle2, replacement2, 1)
step.write_text(s)

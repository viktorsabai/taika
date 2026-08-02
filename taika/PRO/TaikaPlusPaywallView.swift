import SwiftUI
import RevenueCat
import StoreKit

/// Paywall Taika+ — продающий макет по брифу:
/// hero + mascot.favorite · coverflow плюшек как Спикер · trial CTA в brand accent.
struct TaikaPlusPaywallView: View {

    let courseId: String?
    let reason: ProGateReason
    let onClose: () -> Void

    init(courseId: String?, reason: ProGateReason = .general, onClose: @escaping () -> Void) {
        self.courseId = courseId
        self.reason = {
            if reason == .general, let courseId, !courseId.isEmpty {
                return .lockedCourse
            }
            return reason
        }()
        self.onClose = onClose
    }

    @ObservedObject private var pro = ProManager.shared
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var auth = AuthService.shared

    @State private var isLoadingOfferings = false
    @State private var offerings: Offerings?
    @State private var selectedPackageId: String?
    @State private var purchaseInFlight = false
    @State private var purchaseError: String?
    @State private var restoreInFlight = false
    @State private var contentVisible = false
    @State private var perkPage: Int = 0
    /// nil = ещё не проверили; true = Apple intro eligible.
    @State private var introEligible: Bool? = nil
    @State private var showAuthSheet = false
    @State private var authInProgress = false
    @State private var continuePurchaseAfterAuth = false

    /// Каноничный brand-accent (градиент), не solid tint.
    private var accentFill: LinearGradient { theme.currentAccentFill }
    private var accentTint: Color { theme.currentAccentTintColor }

    private var perkSlides: [TaikaValueSlide] { TaikaValueDeck.plus }

    private var selectedPackage: Package? {
        guard let id = selectedPackageId,
              let offering = offerings?.current else { return nil }
        return offering.availablePackages.first { $0.identifier == id }
    }

    private var offersIntroTrial: Bool {
        introEligible == true || (introEligible == nil && selectedPackage?.storeProduct.introductoryDiscount != nil)
    }

    private var primaryCTATitle: String {
        if purchaseInFlight { return "Оформляем…" }
        if isLoadingOfferings, selectedPackage == nil { return "Загружаем…" }
        if !auth.isLoggedIn {
            return offersIntroTrial
                ? "Войти и попробовать \(TaikaProConfig.introTrialDays) дня"
                : "Войти и открыть Taika+"
        }
        if offersIntroTrial {
            return "Попробовать \(TaikaProConfig.introTrialDays) дня бесплатно"
        }
        return reason.ctaFallback
    }

    private var monthlyPriceLine: String {
        if offersIntroTrial {
            if let monthly = offerings?.current?.package(identifier: TaikaProConfig.PackageIdentifier.monthly) {
                return "\(TaikaProConfig.introTrialDays) дня бесплатно, дальше — \(monthly.localizedPriceString) в месяц. Отменить можно в любой момент."
            }
            return "\(TaikaProConfig.introTrialDays) дня бесплатно, дальше — подписка. Отменить можно в любой момент."
        }
        if let monthly = offerings?.current?.package(identifier: TaikaProConfig.PackageIdentifier.monthly) {
            return "Дальше — \(monthly.localizedPriceString) в месяц. Отменить можно в любой момент."
        }
        if let selected = selectedPackage, selected.packageType != .lifetime {
            return "Дальше — \(selected.localizedPriceString). Отменить можно в любой момент."
        }
        return "Дальше — подписка. Отменить можно в любой момент."
    }

    private var canPurchase: Bool {
        RevenueCatBootstrap.isConfigured && selectedPackage != nil && !purchaseInFlight
    }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onClose)

            mainPanel
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .scaleEffect(contentVisible ? 1 : 0.98)
                .opacity(contentVisible ? 1 : 0)
                .animation(.spring(response: 0.36, dampingFraction: 0.92), value: contentVisible)
        }
        .task {
            _ = courseId
            perkPage = TaikaValueDeck.plusStartIndex(for: reason)
            await ProManager.shared.syncRevenueCatIdentity(userId: AuthService.shared.currentUserID)
            await loadOfferingsIfNeeded()
        }
        .onAppear { contentVisible = true }
        .sheet(isPresented: $showAuthSheet) {
            paywallAuthSheet
        }
        .onChange(of: auth.isLoggedIn) { _, loggedIn in
            guard loggedIn, continuePurchaseAfterAuth else { return }
            continuePurchaseAfterAuth = false
            showAuthSheet = false
            Task { await purchaseSelected(requireAuth: true) }
        }
    }

    // MARK: - Panel

    private var mainPanel: some View {
        let panelMaxH = min(UIScreen.main.bounds.height * 0.92, 780)

        return VStack(alignment: .leading, spacing: 0) {
            headerBar

            VStack(alignment: .leading, spacing: 16) {
                heroBlock
                perksBlock
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            bottomOffer
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 4)
        }
        .padding(.top, 2)
        .padding(.bottom, 14)
        .frame(maxWidth: 420)
        .frame(maxHeight: panelMaxH)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(CD.ColorToken.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentTint.opacity(0.10),
                                    Color.clear,
                                    accentTint.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(accentFill.opacity(0.35), lineWidth: Theme.Strokes.strokeCardLineWidth)
        )
        .shadow(color: accentTint.opacity(0.18), radius: 28, y: 16)
        .onTapGesture { }
    }

    private var headerBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(CD.ColorToken.chip.opacity(0.9)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Hero (контекст причины + brand)

    private var heroBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentFill)

                Text(reason.heroTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(CD.ColorToken.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(reason.heroSubtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let courseId, !courseId.isEmpty,
                   let title = CourseData.shared.title(for: courseId)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !title.isEmpty {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentFill)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image("mascot.favorite")
                .resizable()
                .scaledToFit()
                .frame(width: 108, height: 108)
                .taikaMascotChrome()
                .accessibilityHidden(true)
        }
    }

    // MARK: - Perks coverflow — продающие карточки (как Pro teaser / Speaker)

    private var perksBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Что внутри Taika+")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CD.ColorToken.textSecondary)

            perkCoverflow

            HStack(spacing: 6) {
                ForEach(0..<perkSlides.count, id: \.self) { i in
                    Capsule(style: .continuous)
                        .fill(
                            i == perkPage
                            ? AnyShapeStyle(accentFill)
                            : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.28))
                        )
                        .frame(width: i == perkPage ? 20 : 7, height: 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .animation(.easeInOut(duration: 0.25), value: perkPage)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var perkCoverflow: some View {
        GeometryReader { geo in
            let itemW = max(248, geo.size.width * 0.86)
            let itemH = max(210, geo.size.height - 4)
            let current = min(max(0, perkPage), max(0, perkSlides.count - 1))

            ZStack {
                ForEach(Array(perkSlides.enumerated()), id: \.element.id) { index, slide in
                    let rel = index - current
                    perkSellingCard(slide: slide, index: index, total: perkSlides.count, isActive: rel == 0)
                        .frame(width: itemW, height: itemH)
                        .scaleEffect(rel == 0 ? 1.0 : 0.82)
                        .rotation3DEffect(
                            .degrees(Double(rel) * -18),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.7
                        )
                        .opacity(abs(rel) > 2 ? 0 : (rel == 0 ? 1.0 : 0.45))
                        .offset(x: CGFloat(rel) * (itemW * 0.92))
                        .zIndex(rel == 0 ? 10 : Double(10 - abs(rel)))
                        .allowsHitTesting(abs(rel) <= 1)
                        .onTapGesture {
                            guard index != current else { return }
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { perkPage = index }
                        }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > 48, abs(dx) > abs(dy) * 1.15 else { return }
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                            if dx < 0 {
                                perkPage = min(perkPage + 1, perkSlides.count - 1)
                            } else {
                                perkPage = max(perkPage - 1, 0)
                            }
                        }
                    }
            )
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: current)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 220)
    }

    /// Продающая карточка: контент по центру — иконка, польза, подзаголовок.
    private func perkSellingCard(slide: TaikaValueSlide, index: Int, total: Int, isActive: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text("taikA")
                    .font(.custom("ONMARK Trial", size: 14))
                    .tracking(0.6)
                    .foregroundStyle(PD.ColorToken.text)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Taika+")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(accentFill)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(accentFill, lineWidth: 1.2)
                )
            }
            .padding(.bottom, 18)

            Image(systemName: slide.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(accentFill)
                .padding(.bottom, 12)

            Text(slide.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(CD.ColorToken.text)
                .lineLimit(2)
                .minimumScaleFactor(0.88)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

            Text(slide.subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary)
                .lineLimit(3)
                .minimumScaleFactor(0.9)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)

            Spacer(minLength: 10)

            Text("\(index + 1)/\(total)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CD.ColorToken.textSecondary)
                .frame(maxWidth: .infinity)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            ZStack {
                Theme.Surfaces.card(shape)
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                accentTint.opacity(isActive ? 0.16 : 0.08),
                                Color.clear,
                                accentTint.opacity(isActive ? 0.10 : 0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            shape.stroke(
                isActive
                ? AnyShapeStyle(accentFill.opacity(0.55))
                : AnyShapeStyle(Theme.Strokes.strokeSubtle),
                lineWidth: isActive ? Theme.Strokes.strokeCardLineWidth + 0.4 : Theme.Strokes.strokeLineWidth
            )
        )
        .shadow(
            color: isActive ? accentTint.opacity(0.22) : Color.black.opacity(0.16),
            radius: isActive ? 14 : 6,
            y: isActive ? 6 : 3
        )
        .clipShape(shape)
    }

    // MARK: - Bottom offer (триал только для залогиненных)

    private var bottomOffer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let purchaseError {
                Text(purchaseError)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accentFill)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentFill)
                VStack(alignment: .leading, spacing: 2) {
                    Text(offersIntroTrial
                         ? "Попробуй \(TaikaProConfig.introTrialDays) дня бесплатно"
                         : "Taika+ без лимитов")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                    Text(offersIntroTrial
                         ? (auth.isLoggedIn
                            ? "После входа — триал на этот аккаунт."
                            : "Сначала вход — так триал один на человека.")
                         : "Подписка на этот Apple ID / аккаунт.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                }
                Spacer(minLength: 0)
                Text(offersIntroTrial ? "\(TaikaProConfig.introTrialDays) дня" : "Pro")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.86))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(accentFill))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CD.ColorToken.chip.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(accentFill.opacity(0.4), lineWidth: 1.15)
                    )
            )

            Button {
                Task { await primaryCTATapped() }
            } label: {
                HStack(spacing: 8) {
                    if purchaseInFlight || isLoadingOfferings || authInProgress {
                        ProgressView()
                            .tint(Color.black.opacity(0.75))
                    }
                    Text(primaryCTATitle)
                        .font(.system(size: 17, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accentFill)
                )
            }
            .buttonStyle(.plain)
            .disabled(purchaseInFlight || authInProgress)

            Text(monthlyPriceLine)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(CD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            Button {
                Task { await restoreTapped() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text(restoreInFlight ? "Восстановление…" : "У меня уже есть подписка")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(CD.ColorToken.textSecondary)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .disabled(restoreInFlight)

            HStack(spacing: 14) {
                Button("Privacy") {
                    UIApplication.shared.open(TaikaProConfig.Legal.privacyPolicy)
                }
                Button("Terms") {
                    UIApplication.shared.open(TaikaProConfig.Legal.termsOfUse)
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
            .padding(.top, 2)
        }
    }

    private var paywallAuthSheet: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(CD.ColorToken.textSecondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(accentFill)

            Text("Войди, чтобы начать триал")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(CD.ColorToken.text)
                .multilineTextAlignment(.center)

            Text("3 дня Taika+ привязываются к аккаунту — так триал один раз на человека, а Pro не потеряется при смене телефона.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if let purchaseError {
                Text(purchaseError)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accentFill)
                    .multilineTextAlignment(.center)
            }

            Button {
                startPaywallSignIn()
            } label: {
                HStack(spacing: 8) {
                    if authInProgress {
                        ProgressView().tint(.white)
                    }
                    Image(systemName: "apple.logo")
                        .font(.system(size: 16, weight: .semibold))
                    Text(authInProgress ? "Входим…" : "Sign in with Apple")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule(style: .continuous).fill(Color.black))
            }
            .buttonStyle(.plain)
            .disabled(authInProgress)

            Button("Позже") {
                continuePurchaseAfterAuth = false
                showAuthSheet = false
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(CD.ColorToken.textSecondary)
            .disabled(authInProgress)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
        .presentationDetents([.fraction(0.48), .medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                AuthService.presentationWindow = window
            }
        }
    }

    // MARK: - Commerce

    private func loadOfferingsIfNeeded() async {
        guard RevenueCatBootstrap.isConfigured else { return }
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            let o = try await Purchases.shared.offerings()
            offerings = o
            preselectPackage(from: o)
            await refreshIntroEligibility()
        } catch {
            // CTA остаётся.
        }
    }

    private func preselectPackage(from offerings: Offerings) {
        guard let current = offerings.current else { return }
        let order = [
            TaikaProConfig.PackageIdentifier.monthly,
            TaikaProConfig.PackageIdentifier.annual,
            TaikaProConfig.PackageIdentifier.lifetime
        ]
        for id in order {
            if current.package(identifier: id) != nil {
                selectedPackageId = id
                return
            }
        }
        selectedPackageId = current.availablePackages.first?.identifier
    }

    private func refreshIntroEligibility() async {
        guard let pkg = selectedPackage else {
            introEligible = nil
            return
        }
        introEligible = await ProManager.shared.introTrialEligible(for: pkg)
    }

    private func isPurchaseCancelledError(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == ErrorCode.errorDomain && ns.code == ErrorCode.purchaseCancelledError.rawValue
    }

    private func primaryCTATapped() async {
        purchaseError = nil
        if !auth.isLoggedIn {
            continuePurchaseAfterAuth = true
            showAuthSheet = true
            return
        }
        await purchaseSelected(requireAuth: true)
    }

    private func startPaywallSignIn() {
        authInProgress = true
        purchaseError = nil
        Task {
            do {
                try await auth.signInWithApple()
                if let uid = auth.currentUserID {
                    SyncManager.shared.onUserDidLogin(userId: uid)
                    await ProManager.shared.syncRevenueCatIdentity(userId: uid)
                }
                authInProgress = false
                if auth.isLoggedIn, continuePurchaseAfterAuth {
                    continuePurchaseAfterAuth = false
                    showAuthSheet = false
                    await purchaseSelected(requireAuth: true)
                }
            } catch AuthService.AuthError.cancelled {
                authInProgress = false
                continuePurchaseAfterAuth = false
            } catch {
                purchaseError = error.localizedDescription
                authInProgress = false
                continuePurchaseAfterAuth = false
            }
        }
    }

    private func purchaseSelected(requireAuth: Bool) async {
        purchaseError = nil
        if requireAuth, !auth.isLoggedIn {
            continuePurchaseAfterAuth = true
            showAuthSheet = true
            return
        }
        guard RevenueCatBootstrap.isConfigured else {
            purchaseError = "Подписка временно недоступна. Попробуй позже или восстанови покупку."
            return
        }
        await ProManager.shared.syncRevenueCatIdentity(userId: auth.currentUserID)
        guard let pkg = selectedPackage else {
            await loadOfferingsIfNeeded()
            guard let pkg2 = selectedPackage else {
                purchaseError = "Тарифы ещё не загрузились. Нажми ещё раз через секунду."
                return
            }
            await purchase(pkg2)
            return
        }
        await purchase(pkg)
    }

    private func purchase(_ pkg: Package) async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await Purchases.shared.purchase(package: pkg)
            ProManager.shared.applyRevenueCatCustomerInfo(result.customerInfo)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onClose()
        } catch {
            if isPurchaseCancelledError(error) { return }
            purchaseError = "Покупка не прошла. Попробуй ещё раз."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func restoreTapped() async {
        purchaseError = nil
        guard RevenueCatBootstrap.isConfigured else {
            purchaseError = "Восстановление пока недоступно. Попробуй позже."
            return
        }
        if !auth.isLoggedIn {
            continuePurchaseAfterAuth = false
            showAuthSheet = true
            purchaseError = "Войди в аккаунт, чтобы восстановить подписку."
            return
        }
        restoreInFlight = true
        defer { restoreInFlight = false }
        do {
            await ProManager.shared.syncRevenueCatIdentity(userId: auth.currentUserID)
            try await ProManager.shared.restorePurchases()
            if pro.isPro {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onClose()
            } else {
                purchaseError = "Активных покупок не найдено."
            }
        } catch {
            purchaseError = "Не удалось восстановить. Попробуй ещё раз."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TaikaPlusPaywallView(courseId: nil) {}
    }
}

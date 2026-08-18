import SwiftUI
import RevenueCat
import StoreKit

/// Paywall Taika+ — минимальный checkout: оффер + планы + CTA.
/// Value-deck / aha живут до paywall; здесь не дублируем.
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
    @ObservedObject private var trainingAttempts = SpeakerDailyAttemptsStore.shared

    @State private var isLoadingOfferings = false
    @State private var offerings: Offerings?
    @State private var selectedPackageId: String?
    @State private var purchaseInFlight = false
    @State private var purchaseError: String?
    @State private var restoreInFlight = false
    @State private var contentVisible = false
    @State private var ctaPulse = false
    /// nil = ещё не проверили; true = Apple intro eligible.
    @State private var introEligible: Bool? = nil
    @State private var showAuthSheet = false
    @State private var authInProgress = false
    @State private var continuePurchaseAfterAuth = false
    @State private var showProSuccess = false

    private var accentFill: LinearGradient { theme.currentAccentFill }
    private var accentTint: Color { theme.currentAccentTintColor }

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
                ? TaikaProConfig.introTrialCTALogin
                : "Войти и открыть Taika+"
        }
        if offersIntroTrial {
            return TaikaProConfig.introTrialCTAFree
        }
        return reason.ctaFallback
    }

    private var legalLine: String {
        if offersIntroTrial {
            return TaikaProConfig.introTrialLegalLine
        }
        if let selected = selectedPackage, selected.packageType != .lifetime {
            return "Дальше — \(selected.storeProduct.localizedPriceString). Отменить можно в любой момент в настройках Apple ID."
        }
        return "Отменить можно в любой момент в настройках Apple ID."
    }

    private var annualPackage: Package? {
        offerings?.current?.package(identifier: TaikaProConfig.PackageIdentifier.annual)
    }
    private var monthlyPackage: Package? {
        offerings?.current?.package(identifier: TaikaProConfig.PackageIdentifier.monthly)
    }
    private var lifetimePackage: Package? {
        offerings?.current?.package(identifier: TaikaProConfig.PackageIdentifier.lifetime)
    }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onClose)

            mainPanel
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.vertical, 24)
                .scaleEffect(contentVisible ? 1 : 0.96)
                .opacity(contentVisible && !showProSuccess ? 1 : 0)
                .offset(y: contentVisible ? 0 : 18)
                .animation(.spring(response: 0.42, dampingFraction: 0.88), value: contentVisible)
                .allowsHitTesting(!showProSuccess)

            if showProSuccess {
                TaikaProSuccessView {
                    onClose()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.88), value: showProSuccess)
        .task {
            _ = courseId
            await ProManager.shared.syncRevenueCatIdentity(userId: AuthService.shared.currentUserID)
            await loadOfferingsIfNeeded()
        }
        .onAppear {
            contentVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                    ctaPulse = true
                }
            }
        }
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
        GlassSurface(cornerRadius: TaikaOverlayTokens.Layout.cardRadius) {
            VStack(alignment: .leading, spacing: 0) {
                headerBar

                VStack(alignment: .leading, spacing: 16) {
                    sourceContextBlock
                    quotaBlock
                    heroBlock
                    planPicker
                    checkoutBlock
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: 420)
        .overlay {
            RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.cardRadius, style: .continuous)
                .strokeBorder(accentFill.opacity(0.28), lineWidth: Theme.Strokes.strokeCardLineWidth)
        }
        .shadow(color: accentTint.opacity(0.14), radius: 24, y: 14)
        .onTapGesture { }
    }

    @ViewBuilder
    private var sourceContextBlock: some View {
        if reason == .games {
            GlassMessage(title: "Из Game Park", symbol: "gamecontroller.fill") {
                Text("Ты открыл это предложение из закрытого игрового режима. После закрытия вернёшься в Game Park.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var quotaBlock: some View {
        if reason == .speakerBreakdown {
            GlassQuota(
                title: "Попытки Спикера",
                detail: pro.isPro ? "без лимита" : "\(trainingAttempts.remainingToday) осталось сегодня",
                progress: Double(trainingAttempts.remainingToday) / 10.0
            )
        }
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
        .padding(.bottom, 2)
    }

    // MARK: - Hero (только контекст, без маскота / deck)

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reason.heroTitle)
                .font(.system(size: 24, weight: .bold))
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
    }

    // MARK: - Plans

    private var planPicker: some View {
        VStack(spacing: 8) {
            planRow(
                id: TaikaProConfig.PackageIdentifier.annual,
                title: "Год",
                priceLine: annualPriceLine,
                subtitle: annualSubtitle,
                badge: TaikaProConfig.annualHeroBadge,
                isHero: true
            )
            planRow(
                id: TaikaProConfig.PackageIdentifier.monthly,
                title: "Месяц",
                priceLine: monthlyPlanPriceLine,
                subtitle: "Гибкая оплата",
                badge: nil,
                isHero: false
            )
            planRow(
                id: TaikaProConfig.PackageIdentifier.lifetime,
                title: "Навсегда",
                priceLine: lifetimePriceLine,
                subtitle: "Разовая оплата",
                badge: nil,
                isHero: false
            )
        }
    }

    private var annualPriceLine: String {
        if let p = annualPackage {
            return "\(p.storeProduct.localizedPriceString)/год"
        }
        return "\(TaikaProConfig.MarketingPrice.annualTHB.formatted()) ฿/год"
    }

    /// Trial только в CTA/legal — здесь цена и выгода года.
    private var annualSubtitle: String {
        if let p = annualPackage {
            let yearly = (p.storeProduct.price as NSDecimalNumber).doubleValue
            let perMonth = Int((yearly / 12.0).rounded())
            return "≈ \(perMonth) ฿/мес"
        }
        return "≈ \(TaikaProConfig.MarketingPrice.annualPerMonthTHB) ฿/мес"
    }

    private var monthlyPlanPriceLine: String {
        if let p = monthlyPackage {
            return "\(p.storeProduct.localizedPriceString)/мес"
        }
        return "\(TaikaProConfig.MarketingPrice.monthlyTHB.formatted()) ฿/мес"
    }

    private var lifetimePriceLine: String {
        if let p = lifetimePackage {
            return "\(p.storeProduct.localizedPriceString) разово"
        }
        return "\(TaikaProConfig.MarketingPrice.lifetimeTHB.formatted()) ฿ разово"
    }

    private func planRow(
        id: String,
        title: String,
        priceLine: String,
        subtitle: String,
        badge: String?,
        isHero: Bool
    ) -> some View {
        let isSelected = selectedPackageId == id
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            selectedPackageId = id
            Task { await refreshIntroEligibility() }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(CD.ColorToken.text)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.86))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(accentFill))
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                }
                Spacer(minLength: 0)
                Text(priceLine)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isHero && isSelected ? AnyShapeStyle(accentFill) : AnyShapeStyle(CD.ColorToken.text))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                shape
                    .fill(CD.ColorToken.chip.opacity(isSelected ? 0.98 : 0.72))
                    .overlay(
                        shape.strokeBorder(
                            isSelected ? AnyShapeStyle(accentFill.opacity(0.85)) : AnyShapeStyle(Theme.Strokes.strokeSubtle),
                            lineWidth: isSelected ? 1.6 : Theme.Strokes.strokeLineWidth
                        )
                    )
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - CTA + legal + restore

    private var checkoutBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let purchaseError {
                Text(purchaseError)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accentFill)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
            .scaleEffect(ctaPulse ? 1.015 : 1.0)
            .shadow(color: accentTint.opacity(ctaPulse ? 0.35 : 0.18), radius: ctaPulse ? 16 : 8, y: 6)

            Text(legalLine)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(CD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            Button {
                Task { await restoreTapped() }
            } label: {
                Text(restoreInFlight ? "Восстановление…" : "У меня уже есть подписка")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
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

            Text("Триал на \(TaikaProConfig.introTrialDaysPhrase) привязывается к аккаунту — один раз на человека, а Pro не потеряется при смене телефона.")
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
            TaikaProConfig.PackageIdentifier.annual,
            TaikaProConfig.PackageIdentifier.monthly,
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
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                showProSuccess = true
            }
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
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    showProSuccess = true
                }
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

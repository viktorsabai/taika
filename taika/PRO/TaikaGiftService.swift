//
//  TaikaGiftService.swift
//  taika
//
//  Подарок Taika Pro: выдача и активация одноразового кода через Railway API.
//

import Foundation

@MainActor
enum TaikaGiftService {
    enum GiftError: LocalizedError {
        case noAPI
        case badResponse(String)
        case network

        var errorDescription: String? {
            switch self {
            case .noAPI:
                return "Сервер подарков недоступен. Проверь интернет и попробуй позже."
            case .badResponse(let detail):
                return detail
            case .network:
                return "Не удалось связаться с сервером. Попробуй ещё раз."
            }
        }
    }

    private static var baseURL: String? {
        SpeakerManager.toneAssessmentBaseURL
    }

    private static func endpoint(_ path: String) throws -> URL {
        guard let base = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines), !base.isEmpty else {
            throw GiftError.noAPI
        }
        let root = base.hasSuffix("/") ? String(base.dropLast()) : base
        guard let url = URL(string: root + path) else { throw GiftError.noAPI }
        return url
    }

    /// После оплаты gift-SKU — или demo (сервер GIFT_DEMO=1).
    static func issueCode(
        buyerRCId: String?,
        transactionId: String?,
        demo: Bool
    ) async throws -> String {
        let url = try endpoint("/gift/issue")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["demo": demo]
        if let buyerRCId, !buyerRCId.isEmpty { body["buyer_rc_id"] = buyerRCId }
        if let transactionId, !transactionId.isEmpty { body["transaction_id"] = transactionId }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code >= 200, code < 300 else {
            throw GiftError.badResponse(humanDetail(data: data, fallback: "Не удалось выдать код подарка."))
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let giftCode = (json?["code"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !giftCode.isEmpty else {
            throw GiftError.badResponse("Сервер не вернул код.")
        }
        return giftCode
    }

    /// `demoGrant` = сервер активировал без RC secret (GIFT_DEMO) — на клиенте нужен локальный unlock.
    struct RedeemResult: Sendable {
        let demoGrant: Bool
    }

    @discardableResult
    static func redeemCode(_ code: String, appUserId: String) async throws -> RedeemResult {
        let url = try endpoint("/gift/redeem")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 25
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines),
            "app_user_id": appUserId,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status >= 200, status < 300 else {
            throw GiftError.badResponse(humanRedeemDetail(data: data, status: status))
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let demoGrant = (json?["demo_grant"] as? Bool) == true
        return RedeemResult(demoGrant: demoGrant)
    }

    private static func humanDetail(data: Data, fallback: String) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let d = json["detail"] as? String, !d.isEmpty {
                switch d {
                case "demo_disabled":
                    return "Демо-подарки выключены на сервере. Нужна покупка «Подарок» в App Store."
                case "transaction_required":
                    return "Сначала оплати подарок — потом появится код."
                default:
                    return fallback
                }
            }
        }
        return fallback
    }

    private static func humanRedeemDetail(data: Data, status: Int) -> String {
        let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
        switch detail {
        case "not_found":
            return "Такого кода нет. Проверь буквы и попробуй ещё раз."
        case "already_redeemed":
            return "Этот подарок уже активировали."
        case "invalid_format":
            return "Код выглядит иначе. Обычно так: TAIKA-XXXX-XXXX-XXXX."
        case "revenuecat_secret_missing":
            return "Активация пока недоступна на сервере. Напиши в поддержку."
        default:
            if status == 404 { return "Такого кода нет. Проверь буквы и попробуй ещё раз." }
            if status == 409 { return "Этот подарок уже активировали." }
            return "Не удалось активировать подарок. Попробуй ещё раз."
        }
    }
}

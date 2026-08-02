import Foundation

/// Режим взаимодействия с уроком (полный прогресс vs оверлей из избранного).
public enum InteractionScope: Hashable {
    case full
    case overlay
}

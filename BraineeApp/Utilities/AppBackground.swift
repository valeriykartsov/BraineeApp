//
//  AppBackground.swift
//  BraineeApp
//
//  Свой фон приложения (п. 58, D-48): картинка — JPEG-файл в Application Support, не SwiftData и не бэкап;
//  режим, затемнение и размытие — UserDefaults. Картинка декодируется один раз и общая для всех экранов.

import SwiftUI
import UIKit
import CoreImage

enum AppBackgroundMode: String, CaseIterable, Identifiable {
    case none
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Без фона"
        case .image: "Картинка"
        }
    }

    static func resolved(from raw: String?) -> AppBackgroundMode {
        raw.flatMap(AppBackgroundMode.init(rawValue:)) ?? .none
    }
}

enum AppBackgroundSettings {
    static let modeKey = "appBackgroundMode"
    static let dimKey = "appBackgroundDim"
    static let blurKey = "appBackgroundBlur"

    static let defaultDim = 0.4
    static let maxDim = 0.8
    /// Радиус размытия в точках картинки (картинка — размером с экран).
    static let blurRadius: Double = 24

    /// Затемнение в допустимых границах 0…80 %.
    static func clampedDim(_ value: Double) -> Double {
        guard value.isFinite else { return defaultDim }
        return min(max(value, 0), maxDim)
    }

    /// Затемнение из UserDefaults: ключа нет — значение по умолчанию.
    static func dim(defaults: UserDefaults = .standard) -> Double {
        guard defaults.object(forKey: dimKey) != nil else { return defaultDim }
        return clampedDim(defaults.double(forKey: dimKey))
    }

    static func percentText(_ dim: Double) -> String {
        "\(Int((clampedDim(dim) * 100).rounded())) %"
    }
}

enum BackgroundImageScaling {
    /// Длинная сторона — не больше экрана самого большого iPhone (2796 px).
    static let maxLongSide: CGFloat = 2796
    static let jpegQuality: CGFloat = 0.85

    /// Размер в пикселях после уменьшения с сохранением пропорций; меньшие картинки не увеличиваются.
    static func targetSize(for size: CGSize, maxLongSide: CGFloat = maxLongSide) -> CGSize {
        let longSide = max(size.width, size.height)
        guard longSide > maxLongSide, longSide > 0 else { return size }
        let scale = maxLongSide / longSide
        return CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }
}

enum BackgroundImageError: LocalizedError {
    case unreadable

    var errorDescription: String? {
        "Не удалось открыть картинку. Выберите другую."
    }
}

/// Файл картинки фона. Папка — параметр, чтобы тесты работали во временной папке.
struct BackgroundImageFile {
    static let fileName = "background.jpg"

    let directory: URL

    static var appDefault: BackgroundImageFile {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return BackgroundImageFile(directory: support.appendingPathComponent("BraineeApp", isDirectory: true))
    }

    var url: URL { directory.appendingPathComponent(Self.fileName) }

    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    /// Уменьшает картинку до размера экрана и записывает JPEG (атомарно — старый файл не портится при ошибке).
    func save(imageData: Data) throws {
        guard let image = UIImage(data: imageData), let jpeg = Self.jpegData(for: image) else {
            throw BackgroundImageError.unreadable
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try jpeg.write(to: url, options: .atomic)
    }

    func load() -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func delete() throws {
        guard exists else { return }
        try FileManager.default.removeItem(at: url)
    }

    static func jpegData(for image: UIImage) -> Data? {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let target = BackgroundImageScaling.targetSize(for: pixelSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        // Рисуем заново: учитывается ориентация снимка, лишние метаданные (геопозиция) не сохраняются.
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: BackgroundImageScaling.jpegQuality)
    }
}

/// Картинка фона в памяти: одна на всё приложение, размытая версия считается один раз.
@MainActor
final class AppBackgroundStore: ObservableObject {
    static let shared = AppBackgroundStore(file: .appDefault)

    @Published private(set) var image: UIImage?
    @Published private(set) var blurredImage: UIImage?

    private let file: BackgroundImageFile

    init(file: BackgroundImageFile) {
        self.file = file
        reload()
    }

    var hasImage: Bool { image != nil }

    func setImage(data: Data) throws {
        try file.save(imageData: data)
        reload()
    }

    func removeImage() throws {
        try file.delete()
        reload()
    }

    private func reload() {
        image = file.load()
        blurredImage = image.flatMap { Self.blurred($0, radius: AppBackgroundSettings.blurRadius) }
    }

    private static func blurred(_ image: UIImage, radius: Double) -> UIImage? {
        guard let input = CIImage(image: image) else { return nil }
        let output = input
            .clampedToExtent()
            .applyingGaussianBlur(sigma: radius)
            .cropped(to: input.extent)
        guard let cgImage = CIContext().createCGImage(output, from: input.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }
}

// MARK: - Показ

/// Фон экрана: цвет темы или картинка с затемнением. Картинка привязана к экрану, а не к блоку, —
/// вложенные экраны (`appScreenBackground()` внутри вкладки) показывают тот же участок без стыков.
struct AppScreenBackground: ViewModifier {
    var allowsImage: Bool

    @AppStorage(AppBackgroundSettings.modeKey) private var modeRaw = AppBackgroundMode.none.rawValue
    @AppStorage(AppBackgroundSettings.dimKey) private var dim = AppBackgroundSettings.defaultDim
    @AppStorage(AppBackgroundSettings.blurKey) private var blur = false
    @ObservedObject private var store = AppBackgroundStore.shared

    private var picture: UIImage? {
        guard allowsImage, AppBackgroundMode.resolved(from: modeRaw) == .image else { return nil }
        return blur ? (store.blurredImage ?? store.image) : store.image
    }

    func body(content: Content) -> some View {
        content.background {
            if let picture {
                ScreenAnchoredImage(image: picture)
                    .overlay(DesignSystem.Colors.background.opacity(AppBackgroundSettings.clampedDim(dim)))
                    .ignoresSafeArea()
                    // Картинка сдвинута за пределы блока; `clipped()` обрезает только рисование, а не нажатия —
                    // без этого невидимая часть фона списка забирала нажатия кнопок шапки «Задач» (п. 59).
                    .allowsHitTesting(false)
            } else {
                DesignSystem.Colors.background.ignoresSafeArea()
            }
        }
    }
}

/// Картинка размером с экран, сдвинутая так, чтобы в блоке был виден его участок экрана.
private struct ScreenAnchoredImage: View {
    let image: UIImage

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            let screen = UIScreen.main.bounds.size
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: screen.width, height: screen.height)
                .clipped()
                .offset(x: -frame.minX, y: -frame.minY)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Строка навигации: над картинкой — прозрачная (заголовок и кнопки прямо на фоне, как шапки вкладок),
/// иначе — непрозрачный цвет фона (как раньше).
struct AppNavigationBarBackground: ViewModifier {
    @AppStorage(AppBackgroundSettings.modeKey) private var modeRaw = AppBackgroundMode.none.rawValue
    @ObservedObject private var store = AppBackgroundStore.shared

    private var showsImage: Bool {
        AppBackgroundMode.resolved(from: modeRaw) == .image && store.hasImage
    }

    func body(content: Content) -> some View {
        if showsImage {
            content.toolbarBackground(.hidden, for: .navigationBar)
        } else {
            content
                .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

extension View {
    func appNavigationBarBackground() -> some View {
        modifier(AppNavigationBarBackground())
    }
}

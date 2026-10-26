//
//  AppBackgroundTests.swift
//  BraineeAppTests
//
//  Свой фон приложения (п. 58, D-48): режим и затемнение из настроек, уменьшение картинки,
//  файл картинки во временной папке, бэкап без фона.

import Foundation
import Testing
import UIKit
@testable import BraineeApp

struct AppBackgroundTests {
    private let directory: URL
    private var file: BackgroundImageFile { BackgroundImageFile(directory: directory) }

    init() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppBackgroundTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func pngData(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).pngData { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    // Неизвестный или пустой режим — «Без фона».
    @Test func режимБезЗначения_безФона() {
        #expect(AppBackgroundMode.resolved(from: nil) == .none)
        #expect(AppBackgroundMode.resolved(from: "мусор") == .none)
        #expect(AppBackgroundMode.resolved(from: "image") == .image)
    }

    // Затемнение держится в границах 0…80 %; без ключа — 40 %.
    @Test func затемнение_границыИЗначениеПоУмолчанию() throws {
        #expect(AppBackgroundSettings.clampedDim(-0.2) == 0)
        #expect(AppBackgroundSettings.clampedDim(0.95) == 0.8)
        #expect(AppBackgroundSettings.clampedDim(.nan) == 0.4)
        #expect(AppBackgroundSettings.percentText(0.4) == "40 %")

        let defaults = try #require(UserDefaults(suiteName: "AppBackgroundTests-\(UUID().uuidString)"))
        #expect(AppBackgroundSettings.dim(defaults: defaults) == 0.4)
        defaults.set(0.9, forKey: AppBackgroundSettings.dimKey)
        #expect(AppBackgroundSettings.dim(defaults: defaults) == 0.8)
    }

    // Большая картинка уменьшается по длинной стороне с сохранением пропорций, маленькая — не увеличивается.
    @Test func уменьшение_поДлиннойСтороне() {
        #expect(BackgroundImageScaling.targetSize(for: CGSize(width: 4032, height: 3024))
                == CGSize(width: 2796, height: 2097))
        #expect(BackgroundImageScaling.targetSize(for: CGSize(width: 1000, height: 2000))
                == CGSize(width: 1000, height: 2000))
    }

    // Сохранение пишет JPEG уменьшенного размера; удаление убирает файл.
    @Test func сохранениеИУдаление_файлКартинки() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try file.save(imageData: pngData(width: 3000, height: 1500))

        #expect(file.exists)
        let saved = try #require(file.load())
        #expect(saved.size.width * saved.scale == 2796)
        let header = try Data(contentsOf: file.url).prefix(2)
        #expect(header == Data([0xFF, 0xD8]))   // JPEG

        try file.delete()
        #expect(!file.exists)
        try file.delete()   // повторное удаление — без ошибки
    }

    // Не картинка — ошибка, прежний файл не тронут.
    @Test func неКартинка_ошибкаПрежнийФайлЦел() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try file.save(imageData: pngData(width: 100, height: 200))
        let before = try Data(contentsOf: file.url)

        #expect(throws: BackgroundImageError.self) {
            try file.save(imageData: Data("не картинка".utf8))
        }
        #expect(try Data(contentsOf: file.url) == before)
    }

    // Хранилище в памяти: после выбора есть картинка и размытая версия, после удаления — нет.
    @MainActor
    @Test func хранилище_выборИУдаление() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppBackgroundStore(file: file)
        #expect(!store.hasImage)

        try store.setImage(data: pngData(width: 120, height: 240))
        #expect(store.hasImage)
        #expect(store.blurredImage != nil)

        try store.removeImage()
        #expect(!store.hasImage)
        #expect(store.blurredImage == nil)
    }
}

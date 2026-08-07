//
//  PlatformImage.swift
//  BraineeApp
//
//  Превращает Data (байты картинки) в SwiftUI Image на iOS и macOS.

import SwiftUI

enum PlatformImage {
    static func make(from data: Data) -> Image? {
#if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
#else
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
#endif
    }
}

#if os(iOS)
import UIKit
#else
import AppKit
#endif

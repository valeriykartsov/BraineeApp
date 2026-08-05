//
//  Item.swift
//  BraineeApp
//
//  Created by Valera Valera on 05.08.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

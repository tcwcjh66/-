import SwiftUI
import UIKit

/// 进度照：只存文件名，图放 Documents/twprogress，不进 UserDefaults。
struct ProgressPhoto: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: String       // yyyy-MM-dd
    var file: String
    var note: String = ""
    var kg: Double = 0     // 当天体重，没记就是 0
}

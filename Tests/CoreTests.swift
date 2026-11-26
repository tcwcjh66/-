import XCTest
import CoreGraphics

/// 只覆盖能独立编译的纯逻辑：分组、匹配、搜索。
/// 这些一旦被改坏，拍照识别的结果会全线漂移，所以放进 CI 当护栏。
/// 不碰 UI、不碰 TWStore，避免测试依赖模拟器里的持久化状态。
final class CoreTests: XCTestCase {

    private func word(_ t: String, _ x: CGFloat, _ y: CGFloat) -> OCRWord {
        OCRWord(text: t, box: CGRect(x: x, y: y, width: 0.09, height: 0.02))
    }

    /// 同一行左右两包零食，横向隔开 0.6，必须拆成两组。
    /// 拆不开就会把两包的字搅在一起排名，最后只出四条无关结果。
    func testClustersSplitTwoPacksOnSameRow() {
        let packA = [word("卫龙", 0.10, 0.30),
                     word("魔芋爽", 0.20, 0.30),
                     word("香辣", 0.30, 0.30)]
        let packB = [word("乐事", 0.70, 0.30),
                     word("薯片", 0.80, 0.30)]
        let groups = FoodOCR.clusters(packA + packB)
        XCTAssertEqual(groups.count, 2,
                       "两包该拆成两组，实际 \(groups.map { $0.map { $0.text } })")
    }

    /// 同一包上下三行，纵差小、横差小，必须归成一组。
    func testClustersKeepOnePackTogether() {
        let pack = [word("卫龙", 0.12, 0.31),
                    word("魔芋爽", 0.12, 0.28),
                    word("净含量", 0.13, 0.25)]
        XCTAssertEqual(FoodOCR.clusters(pack).count, 1,
                       "一包上的字不该拆开")
    }

    /// 三个明确的包装词，至少要命中一条，不能全空。
    func testMatchReturnsSomethingForKnownSnack() {
        let pack = [word("卫龙", 0.10, 0.30),
                    word("魔芋爽", 0.20, 0.30),
                    word("香辣", 0.30, 0.30)]
        let hits = FoodOCR.match(pack)
        XCTAssertFalse(hits.isEmpty, "卫龙魔芋爽香辣 应该至少命中一条")
    }

    /// 竖排字要单独成组，不能被并进横排那一组。
    func testClustersSeparateRotatedWords() {
        var vertical = OCRWord(text: "魔芋爽", box: CGRect(x: 0.55, y: 0.20, width: 0.02, height: 0.12))
        vertical.rotated = true
        let flat = [word("卫龙", 0.10, 0.30), word("香辣", 0.20, 0.30)]
        let groups = FoodOCR.clusters(flat + [vertical])
        XCTAssertEqual(groups.count, 2, "竖排词应该自己一组")
    }

    /// 品牌名要能搜到，包装上只印 logo 时靠这条兜底
    func testSearchByBrand() {
        let r = FoodBase.search("乐事", limit: 5)
        XCTAssertFalse(r.isEmpty, "按品牌搜不到乐事")
    }

    /// 别名也要能搜到
    func testSearchByAlias() {
        let r = FoodBase.search("薯片", limit: 8)
        XCTAssertFalse(r.isEmpty, "按“薯片”搜不到东西")
    }

    /// 库不能有重名：重名会让匹配永远只返回第一条，别的同款被吃掉
    func testFoodBaseHasNoDuplicateNames() {
        let names = Set(FoodBase.items.map { $0.name })
        XCTAssertEqual(names.count, FoodBase.items.count,
                       "食物库有重名：\(FoodBase.items.count - names.count) 条")
    }
}

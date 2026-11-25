import Foundation

/// 内置食物库：常见主食、菜、零食、饮料、快餐，每 100g 的实测/标准参考值。
/// 搜不到的东西走联网（Open Food Facts）或扫条码，那两种拿的是厂商官方数据。
struct LocalFood: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var group: String
    var kcal: Double
    var protein: Double
    var carb: Double
    var fat: Double
    var fiber: Double = 0
    /// 常见一份的克数（米饭一碗 150、一个苹果 200 这种）
    var portion: Double = 100

    var macroLine: String {
        String(format: "每100g  %.0f kcal · 蛋白 %.1f · 碳水 %.1f · 脂肪 %.1f",
               kcal, protein, carb, fat)
    }
}

enum FoodBase {
    static func search(_ q: String, limit: Int = 40) -> [LocalFood] {
        let key = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return Array(items.prefix(limit)) }
        let hits = items.filter {
            $0.name.lowercased().contains(key) || $0.group.lowercased().contains(key)
        }
        // 名称开头匹配的排前面
        let ranked = hits.sorted { a, b in
            let A = a.name.lowercased().hasPrefix(key) ? 0 : 1
            let B = b.name.lowercased().hasPrefix(key) ? 0 : 1
            return A == B ? a.name.count < b.name.count : A < B
        }
        return Array(ranked.prefix(limit))
    }

    static let items: [LocalFood] = [
        // ===== 主食 =====
        LocalFood(name: "白米饭", group: "主食", kcal: 116, protein: 2.6, carb: 25.9, fat: 0.3, portion: 150),
        LocalFood(name: "糙米饭", group: "主食", kcal: 112, protein: 2.6, carb: 23.0, fat: 0.9, fiber: 1.6, portion: 150),
        LocalFood(name: "馒头", group: "主食", kcal: 223, protein: 7.0, carb: 47.0, fat: 1.1, portion: 100),
        LocalFood(name: "花卷", group: "主食", kcal: 214, protein: 6.4, carb: 45.6, fat: 1.0, portion: 100),
        LocalFood(name: "煮面条", group: "主食", kcal: 110, protein: 3.5, carb: 22.0, fat: 0.4, portion: 200),
        LocalFood(name: "煮米粉", group: "主食", kcal: 109, protein: 1.8, carb: 24.0, fat: 0.3, portion: 200),
        LocalFood(name: "白粥", group: "主食", kcal: 46, protein: 1.1, carb: 9.9, fat: 0.2, portion: 300),
        LocalFood(name: "小米粥", group: "主食", kcal: 46, protein: 1.4, carb: 8.4, fat: 0.7, portion: 300),
        LocalFood(name: "燕麦片（干）", group: "主食", kcal: 377, protein: 13.2, carb: 66.9, fat: 6.7, fiber: 10.0, portion: 40),
        LocalFood(name: "全麦面包", group: "主食", kcal: 246, protein: 9.0, carb: 43.0, fat: 3.3, fiber: 6.0, portion: 35),
        LocalFood(name: "白吐司", group: "主食", kcal: 265, protein: 8.9, carb: 49.0, fat: 3.3, portion: 30),
        LocalFood(name: "油条", group: "主食", kcal: 388, protein: 6.9, carb: 51.0, fat: 17.6, portion: 60),
        LocalFood(name: "猪肉水饺", group: "主食", kcal: 240, protein: 9.0, carb: 29.0, fat: 9.0, portion: 200),
        LocalFood(name: "肉包子", group: "主食", kcal: 227, protein: 8.0, carb: 30.0, fat: 7.0, portion: 100),
        LocalFood(name: "煮玉米", group: "主食", kcal: 112, protein: 4.0, carb: 22.8, fat: 1.2, fiber: 2.9, portion: 150),
        LocalFood(name: "蒸红薯", group: "主食", kcal: 99, protein: 1.1, carb: 24.7, fat: 0.2, fiber: 1.6, portion: 150),
        LocalFood(name: "蒸土豆", group: "主食", kcal: 81, protein: 2.0, carb: 17.8, fat: 0.2, portion: 150),
        LocalFood(name: "藜麦（煮）", group: "主食", kcal: 120, protein: 4.4, carb: 21.3, fat: 1.9, fiber: 2.8, portion: 150),

        // ===== 蛋白 =====
        LocalFood(name: "鸡胸肉", group: "蛋白", kcal: 133, protein: 24.6, carb: 0.6, fat: 1.9, portion: 120),
        LocalFood(name: "鸡腿肉（去皮）", group: "蛋白", kcal: 146, protein: 20.0, carb: 0, fat: 7.2, portion: 120),
        LocalFood(name: "猪里脊", group: "蛋白", kcal: 155, protein: 20.2, carb: 0.7, fat: 7.9, portion: 120),
        LocalFood(name: "瘦牛肉", group: "蛋白", kcal: 143, protein: 20.2, carb: 2.4, fat: 6.2, portion: 120),
        LocalFood(name: "瘦羊肉", group: "蛋白", kcal: 118, protein: 20.5, carb: 0.2, fat: 3.9, portion: 120),
        LocalFood(name: "三文鱼", group: "蛋白", kcal: 139, protein: 20.4, carb: 0, fat: 7.8, portion: 120),
        LocalFood(name: "鲈鱼", group: "蛋白", kcal: 105, protein: 18.6, carb: 0, fat: 3.4, portion: 150),
        LocalFood(name: "虾", group: "蛋白", kcal: 93, protein: 18.6, carb: 2.8, fat: 0.8, portion: 100),
        LocalFood(name: "鸡蛋", group: "蛋白", kcal: 144, protein: 13.3, carb: 2.8, fat: 8.8, portion: 50),
        LocalFood(name: "蛋白（去黄）", group: "蛋白", kcal: 52, protein: 11.0, carb: 0.7, fat: 0.1, portion: 33),
        LocalFood(name: "北豆腐", group: "蛋白", kcal: 98, protein: 12.2, carb: 3.0, fat: 4.8, portion: 100),
        LocalFood(name: "南豆腐", group: "蛋白", kcal: 61, protein: 6.2, carb: 2.4, fat: 3.0, portion: 100),
        LocalFood(name: "无糖豆浆", group: "蛋白", kcal: 31, protein: 3.0, carb: 1.2, fat: 1.6, portion: 300),
        LocalFood(name: "千张（豆皮）", group: "蛋白", kcal: 262, protein: 24.5, carb: 5.5, fat: 16.0, portion: 80),

        // ===== 蔬菜 =====
        LocalFood(name: "西兰花", group: "蔬菜", kcal: 34, protein: 4.1, carb: 4.3, fat: 0.6, fiber: 1.6, portion: 150),
        LocalFood(name: "菠菜", group: "蔬菜", kcal: 23, protein: 2.6, carb: 2.8, fat: 0.3, fiber: 1.7, portion: 150),
        LocalFood(name: "生菜", group: "蔬菜", kcal: 15, protein: 1.4, carb: 2.0, fat: 0.3, portion: 100),
        LocalFood(name: "黄瓜", group: "蔬菜", kcal: 15, protein: 0.8, carb: 2.9, fat: 0.2, portion: 150),
        LocalFood(name: "番茄", group: "蔬菜", kcal: 15, protein: 0.9, carb: 3.3, fat: 0.2, portion: 150),
        LocalFood(name: "胡萝卜", group: "蔬菜", kcal: 39, protein: 1.0, carb: 8.8, fat: 0.2, fiber: 1.1, portion: 100),
        LocalFood(name: "青椒", group: "蔬菜", kcal: 22, protein: 1.0, carb: 5.4, fat: 0.2, portion: 100),
        LocalFood(name: "洋葱", group: "蔬菜", kcal: 39, protein: 1.1, carb: 9.0, fat: 0.1, portion: 100),
        LocalFood(name: "大白菜", group: "蔬菜", kcal: 17, protein: 1.5, carb: 3.2, fat: 0.1, portion: 200),
        LocalFood(name: "香菇", group: "蔬菜", kcal: 26, protein: 2.2, carb: 5.2, fat: 0.3, portion: 100),
        LocalFood(name: "茄子", group: "蔬菜", kcal: 23, protein: 1.1, carb: 4.9, fat: 0.2, portion: 150),
        LocalFood(name: "豆角", group: "蔬菜", kcal: 30, protein: 1.9, carb: 5.7, fat: 0.2, portion: 150),

        // ===== 水果 =====
        LocalFood(name: "苹果", group: "水果", kcal: 53, protein: 0.2, carb: 13.5, fat: 0.2, fiber: 2.4, portion: 200),
        LocalFood(name: "香蕉", group: "水果", kcal: 93, protein: 1.4, carb: 22.0, fat: 0.2, fiber: 1.2, portion: 120),
        LocalFood(name: "橙子", group: "水果", kcal: 48, protein: 0.8, carb: 11.1, fat: 0.2, fiber: 0.6, portion: 200),
        LocalFood(name: "西瓜", group: "水果", kcal: 31, protein: 0.5, carb: 6.8, fat: 0.3, portion: 300),
        LocalFood(name: "葡萄", group: "水果", kcal: 45, protein: 0.5, carb: 10.3, fat: 0.2, portion: 150),
        LocalFood(name: "蓝莓", group: "水果", kcal: 57, protein: 0.7, carb: 14.5, fat: 0.3, fiber: 2.4, portion: 100),
        LocalFood(name: "草莓", group: "水果", kcal: 32, protein: 1.0, carb: 7.1, fat: 0.2, portion: 150),
        LocalFood(name: "梨", group: "水果", kcal: 51, protein: 0.3, carb: 13.1, fat: 0.1, portion: 200),
        LocalFood(name: "芒果", group: "水果", kcal: 35, protein: 0.6, carb: 8.3, fat: 0.2, portion: 150),
        LocalFood(name: "猕猴桃", group: "水果", kcal: 61, protein: 0.8, carb: 14.5, fat: 0.6, fiber: 2.1, portion: 100),
        LocalFood(name: "火龙果", group: "水果", kcal: 55, protein: 1.1, carb: 13.3, fat: 0.2, portion: 200),
        LocalFood(name: "牛油果", group: "水果", kcal: 160, protein: 2.0, carb: 8.5, fat: 14.7, fiber: 6.7, portion: 100),

        // ===== 乳制品 =====
        LocalFood(name: "全脂牛奶", group: "乳制品", kcal: 61, protein: 3.3, carb: 4.8, fat: 3.3, portion: 250),
        LocalFood(name: "脱脂牛奶", group: "乳制品", kcal: 34, protein: 3.4, carb: 5.0, fat: 0.2, portion: 250),
        LocalFood(name: "希腊酸奶（无糖）", group: "乳制品", kcal: 59, protein: 10.0, carb: 3.6, fat: 0.4, portion: 150),
        LocalFood(name: "原味酸奶", group: "乳制品", kcal: 72, protein: 3.2, carb: 9.3, fat: 2.7, portion: 150),
        LocalFood(name: "切达奶酪", group: "乳制品", kcal: 403, protein: 25.0, carb: 1.3, fat: 33.1, portion: 30),
        LocalFood(name: "黄油", group: "乳制品", kcal: 717, protein: 0.9, carb: 0.1, fat: 81.1, portion: 10),

        // ===== 坚果 =====
        LocalFood(name: "混合坚果", group: "坚果", kcal: 607, protein: 20.0, carb: 21.0, fat: 54.0, fiber: 8.0, portion: 30),
        LocalFood(name: "炒花生", group: "坚果", kcal: 567, protein: 25.8, carb: 16.1, fat: 49.2, portion: 30),
        LocalFood(name: "核桃", group: "坚果", kcal: 646, protein: 14.9, carb: 19.6, fat: 58.8, portion: 20),
        LocalFood(name: "巴旦木", group: "坚果", kcal: 578, protein: 21.2, carb: 21.6, fat: 49.9, portion: 25),
        LocalFood(name: "每日坚果（袋装）", group: "坚果", kcal: 600, protein: 20.0, carb: 20.0, fat: 52.0, portion: 25),

        // ===== 零食 =====
        LocalFood(name: "薯片（原味）", group: "零食", kcal: 536, protein: 7.0, carb: 53.0, fat: 34.0, portion: 70),
        LocalFood(name: "乐事薯片", group: "零食", kcal: 536, protein: 6.6, carb: 52.0, fat: 33.0, portion: 70),
        LocalFood(name: "奥利奥饼干", group: "零食", kcal: 480, protein: 4.8, carb: 68.0, fat: 20.0, portion: 30),
        LocalFood(name: "辣条", group: "零食", kcal: 480, protein: 9.0, carb: 50.0, fat: 25.0, portion: 50),
        LocalFood(name: "士力架", group: "零食", kcal: 500, protein: 8.0, carb: 57.0, fat: 26.0, portion: 51),
        LocalFood(name: "牛奶巧克力", group: "零食", kcal: 550, protein: 7.0, carb: 57.0, fat: 32.0, portion: 25),
        LocalFood(name: "费列罗", group: "零食", kcal: 600, protein: 8.0, carb: 45.0, fat: 40.0, portion: 12),
        LocalFood(name: "旺旺雪饼", group: "零食", kcal: 470, protein: 6.0, carb: 70.0, fat: 17.0, portion: 40),
        LocalFood(name: "好丽友派", group: "零食", kcal: 420, protein: 5.0, carb: 55.0, fat: 20.0, portion: 28),
        LocalFood(name: "趣多多", group: "零食", kcal: 470, protein: 5.0, carb: 65.0, fat: 22.0, portion: 30),
        LocalFood(name: "百奇饼干", group: "零食", kcal: 500, protein: 7.0, carb: 60.0, fat: 25.0, portion: 40),
        LocalFood(name: "梳打饼干", group: "零食", kcal: 430, protein: 8.0, carb: 65.0, fat: 14.0, portion: 30),
        LocalFood(name: "猪肉脯", group: "零食", kcal: 400, protein: 45.0, carb: 20.0, fat: 15.0, portion: 50),
        LocalFood(name: "奶油爆米花", group: "零食", kcal: 500, protein: 6.0, carb: 60.0, fat: 28.0, portion: 50),
        LocalFood(name: "果冻", group: "零食", kcal: 70, protein: 0.1, carb: 17.0, fat: 0.1, portion: 100),
        LocalFood(name: "香草冰淇淋", group: "零食", kcal: 207, protein: 3.5, carb: 24.0, fat: 11.0, portion: 100),
        LocalFood(name: "雪糕", group: "零食", kcal: 220, protein: 3.0, carb: 25.0, fat: 12.0, portion: 80),
        LocalFood(name: "蛋挞", group: "零食", kcal: 375, protein: 5.0, carb: 33.0, fat: 23.0, portion: 60),
        LocalFood(name: "沙琪玛", group: "零食", kcal: 470, protein: 6.0, carb: 62.0, fat: 20.0, portion: 40),

        // ===== 饮料 =====
        LocalFood(name: "可口可乐", group: "饮料", kcal: 43, protein: 0, carb: 10.6, fat: 0, portion: 330),
        LocalFood(name: "百事可乐", group: "饮料", kcal: 43, protein: 0, carb: 11.0, fat: 0, portion: 330),
        LocalFood(name: "雪碧", group: "饮料", kcal: 40, protein: 0, carb: 10.0, fat: 0, portion: 330),
        LocalFood(name: "零度可乐", group: "饮料", kcal: 0, protein: 0, carb: 0, fat: 0, portion: 330),
        LocalFood(name: "元气森林", group: "饮料", kcal: 0, protein: 0, carb: 3.0, fat: 0, portion: 480),
        LocalFood(name: "红牛", group: "饮料", kcal: 46, protein: 0.2, carb: 11.0, fat: 0, portion: 250),
        LocalFood(name: "东鹏特饮", group: "饮料", kcal: 45, protein: 0, carb: 11.0, fat: 0, portion: 250),
        LocalFood(name: "矿泉水", group: "饮料", kcal: 0, protein: 0, carb: 0, fat: 0, portion: 550),
        LocalFood(name: "美式咖啡（无糖）", group: "饮料", kcal: 2, protein: 0.1, carb: 0, fat: 0, portion: 350),
        LocalFood(name: "拿铁（全脂奶）", group: "饮料", kcal: 55, protein: 3.0, carb: 4.5, fat: 3.0, portion: 350),
        LocalFood(name: "珍珠奶茶（全糖）", group: "饮料", kcal: 90, protein: 1.0, carb: 16.0, fat: 3.0, portion: 500),
        LocalFood(name: "鲜榨橙汁", group: "饮料", kcal: 45, protein: 0.7, carb: 10.4, fat: 0.2, portion: 300),
        LocalFood(name: "啤酒", group: "饮料", kcal: 43, protein: 0.5, carb: 3.6, fat: 0, portion: 330),
        LocalFood(name: "白酒（52度）", group: "饮料", kcal: 298, protein: 0, carb: 0, fat: 0, portion: 50),

        // ===== 快餐 =====
        LocalFood(name: "巨无霸汉堡", group: "快餐", kcal: 257, protein: 13.0, carb: 21.0, fat: 12.0, portion: 215),
        LocalFood(name: "麦当劳中薯条", group: "快餐", kcal: 312, protein: 3.4, carb: 41.0, fat: 15.0, portion: 115),
        LocalFood(name: "肯德基原味鸡", group: "快餐", kcal: 260, protein: 22.0, carb: 8.0, fat: 16.0, portion: 100),
        LocalFood(name: "披萨", group: "快餐", kcal: 266, protein: 11.0, carb: 33.0, fat: 10.0, portion: 200),
        LocalFood(name: "牛肉汉堡", group: "快餐", kcal: 250, protein: 13.0, carb: 30.0, fat: 9.0, portion: 200),
        LocalFood(name: "炸鸡腿", group: "快餐", kcal: 250, protein: 20.0, carb: 10.0, fat: 15.0, portion: 100),
        LocalFood(name: "蛋炒饭", group: "快餐", kcal: 185, protein: 5.5, carb: 26.0, fat: 6.0, portion: 300),

        // ===== 家常菜 =====
        LocalFood(name: "番茄炒蛋", group: "家常菜", kcal: 80, protein: 4.5, carb: 4.5, fat: 5.0, portion: 200),
        LocalFood(name: "青椒肉丝", group: "家常菜", kcal: 150, protein: 10.0, carb: 6.0, fat: 11.0, portion: 200),
        LocalFood(name: "红烧肉", group: "家常菜", kcal: 470, protein: 10.0, carb: 8.0, fat: 45.0, portion: 150),
        LocalFood(name: "宫保鸡丁", group: "家常菜", kcal: 190, protein: 13.0, carb: 10.0, fat: 12.0, portion: 200),
        LocalFood(name: "麻婆豆腐", group: "家常菜", kcal: 130, protein: 7.0, carb: 5.0, fat: 9.0, portion: 200),
        LocalFood(name: "鱼香肉丝", group: "家常菜", kcal: 170, protein: 9.0, carb: 11.0, fat: 11.0, portion: 200),
        LocalFood(name: "炒青菜", group: "家常菜", kcal: 70, protein: 1.5, carb: 4.0, fat: 5.5, portion: 200),
        LocalFood(name: "清蒸鱼", group: "家常菜", kcal: 110, protein: 18.0, carb: 1.0, fat: 3.0, portion: 200),
        LocalFood(name: "麻辣烫", group: "家常菜", kcal: 130, protein: 6.0, carb: 12.0, fat: 7.0, portion: 400),
        LocalFood(name: "白切鸡", group: "家常菜", kcal: 198, protein: 20.0, carb: 0.5, fat: 13.0, portion: 150),
        LocalFood(name: "西红柿鸡蛋面", group: "家常菜", kcal: 130, protein: 5.0, carb: 20.0, fat: 3.5, portion: 350),
    ]
}

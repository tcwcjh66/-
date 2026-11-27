import SwiftUI
import UIKit
import PhotosUI

struct DietPage: View {
    @EnvironmentObject var store: TWStore
    @State private var showPicker = false
    @State private var picks: [PhotosPickerItem] = []
    @State private var analyzing = false
    @State private var hits: [FoodHit] = []
    @State private var shotWords: [String] = []
    /// 这一轮的识别过程，给调试台用
    @State private var shotDiag: [String] = []
    @State private var showResult = false
    @State private var showAI = false
    @State private var copiedCount: Int?
    @State private var showFoodSearch = false
    @State private var showScanSheet = false
    @State private var previewPhoto = ""
    @State private var showPhoto = false
    @State private var monthOffset = 0
    @State private var showDay = false
    @State private var detailKey = ""

    private let slots = ["早餐", "午餐", "晚餐", "加餐"]

    private var remaining: Double { max(store.dietTarget - store.dietKcal, 0) }

    /// 按当前时间推断餐次
    private var autoSlot: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<10:  return "早餐"
        case 10..<15: return "午餐"
        case 15..<21: return "晚餐"
        default:      return "加餐"
        }
    }

    private func meals(in slot: String) -> [MealEntry] {
        store.meals.filter { ($0.slot ?? "加餐") == slot }
    }

    private func kcal(in slot: String) -> Int {
        Int(meals(in: slot).reduce(0) { $0 + $1.kcal })
    }

    private func slotTint(_ s: String) -> Color {
        switch s {
        case "早餐": return TWColor.amber
        case "午餐": return TWColor.mint
        case "晚餐": return TWColor.purple
        default:     return TWColor.blue
        }
    }

    private var recentLogs: [DayLog] { Array(store.logs.suffix(7)) }

    private var dayLabels: [String] {
        recentLogs.map { log in
            let p = log.id.split(separator: "-")
            return p.count == 3 ? "\(p[1])/\(p[2])" : log.id
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            PageHeader(title: "饮食", subtitle: "今日摄入 · 拍照识别")
            aiCard
            kcalCard
            macroCard
            nextBiteCard
            proteinSpreadCard
            fixCard
            addCard
            searchCard
            if !store.todayPhotos.isEmpty { photoCard }
            slotSection
            monthCard
            trendCard
            weekCard
        }
        .sheet(isPresented: $showPicker) {
            FoodPicker(defaultSlot: autoSlot) { item in
                store.addMeal(item)
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showResult) {
            ShotResultSheet(hits: hits, defaultSlot: autoSlot, words: shotWords, diag: shotDiag,
                            onGoSearch: { afterDismiss { showFoodSearch = true } },
                            onGoScan: { afterDismiss { showScanSheet = true } }) { hit in
                store.addMeal(MealEntry(
                    name: hit.name,
                    grams: hit.grams,
                    kcal: hit.kcal,
                    protein: hit.protein,
                    carb: hit.carb,
                    fat: hit.fat,
                    veg: hit.veg,
                    slot: autoSlot,
                    time: Date()
                ))
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showFoodSearch) {
            FoodSearchSheet(defaultSlot: autoSlot)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showScanSheet) {
            BarcodeScanSheet(slot: autoSlot)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showPhoto) {
            ZStack {
                Color.black.ignoresSafeArea()
                if let img = UIImage(contentsOfFile: store.photoURL(previewPhoto).path) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                }
            }
            .overlay(alignment: .topTrailing) {
                Button { showPhoto = false } label: {
                    Image(systemName: "xmark")
                        .font(.tw(13, .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background { Circle().fill(.white.opacity(0.18)) }
                }
                .buttonStyle(.plain)
                .padding(16)
            }
            .presentationBackground(.black)
        }
        .sheet(isPresented: $showDay) {
            DietDaySheet(key: detailKey)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showAI) {
            AIChatSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .onChange(of: picks) { _, newValue in
            guard !newValue.isEmpty else { return }
            analyzing = true
            let boost = eatBoost
            let items = Array(newValue.prefix(3))
            Task {
                var all: [FoodHit] = []
                var words: [String] = []
                var diags: [String] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        // 顺便把这张照片存进今天的餐食照片，不靠识别也能留个证据
                        if let jpeg = img.jpegData(compressionQuality: 0.75) {
                            await MainActor.run { _ = store.saveMealPhoto(data: jpeg) }
                        }
                        // 读包装上的字要跑 Vision，放后台，别卡住转圈
                        let t0 = Date()
                        let found = await Task.detached(priority: .userInitiated) {
                            FoodVision.analyzeDetailed(img, boost: boost)
                        }.value
                        TWLog.add("ocr", String(format: "识别 %.2fs · 命中 %d 条 · 读到 %d 个字块",
                                                Date().timeIntervalSince(t0),
                                                found.hits.count,
                                                found.words.count))
                        all = mergeHits(all, found.hits)
                        words += found.words
                        diags += found.diag
                    }
                }
                await MainActor.run {
                    hits = all
                    shotWords = words
                    shotDiag = diags
                    analyzing = false
                    picks = []
                    showResult = true
                }
            }
        }
    }

    /// 近 30 天常吃的，模糊命中时优先推它，最多加 6 分
    private var eatBoost: [String: Double] {
        let cutoff = Date().addingTimeInterval(-30 * 86400)
        var c: [String: Int] = [:]
        for m in store.meals {
            guard let t = m.time, t > cutoff else { continue }
            c[m.name, default: 0] += 1
        }
        guard let top = c.values.max(), top > 0 else { return [:] }
        return c.mapValues { min(6, Double($0) * 6 / Double(top)) }
    }

    /// 多张照片各认各的，同款把克数和热量加起来
    private func mergeHits(_ base: [FoodHit], _ add: [FoodHit]) -> [FoodHit] {
        var out = base
        for h in add {
            if let i = out.firstIndex(where: { $0.name == h.name }) {
                out[i].grams += h.grams
                out[i].kcal += h.kcal
                out[i].protein += h.protein
                out[i].carb += h.carb
                out[i].fat += h.fat
                out[i].veg += h.veg
                out[i].confidence = max(out[i].confidence, h.confidence)
            } else {
                out.append(h)
            }
        }
        return out
    }

    /// 关掉当前弹窗再开下一个，SwiftUI 不允许两个 sheet 叠着开
    private func afterDismiss(_ action: @escaping () -> Void) {
        showResult = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: action)
    }

    // MARK: - 饮食月历

    private var monthAnchor: Date {
        Calendar.current.date(byAdding: .month, value: -monthOffset, to: Date()) ?? Date()
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月"
        return f.string(from: monthAnchor)
    }

    /// 周一起头的月格，nil 是月初那几格空位
    private var monthCells: [Date?] {
        let cal = Calendar.current
        guard let first = cal.date(from: cal.dateComponents([.year, .month], from: monthAnchor)),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let weekday = cal.component(.weekday, from: first)
        let pad = (weekday + 5) % 7
        var out: [Date?] = Array(repeating: nil, count: pad)
        for d in range {
            out.append(cal.date(byAdding: .day, value: d - 1, to: first))
        }
        return out
    }

    private func dayKey(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private func kcalOf(_ d: Date) -> Double? {
        if Calendar.current.isDateInToday(d) { return store.dietKcal }
        guard let list = store.mealHistory[dayKey(d)], !list.isEmpty else { return nil }
        return list.reduce(0) { $0 + $1.kcal }
    }

    private func cellStyle(_ d: Date) -> (Color, Bool) {
        guard let k = kcalOf(d), store.dietTarget > 0 else { return (TWColor.ink3.opacity(0.10), false) }
        let r = k / store.dietTarget
        if r < 0.5 { return (TWColor.blue.opacity(0.38), true) }
        if r < 0.88 { return (TWColor.blue.opacity(0.72), true) }
        if r <= 1.15 { return (TWColor.mint, true) }
        return (TWColor.coral, true)
    }

    private var monthStat: (days: Int, hit: Int, avg: Int) {
        var days = 0
        var hit = 0
        var sum = 0.0
        for c in monthCells {
            guard let d = c, let k = kcalOf(d) else { continue }
            days += 1
            sum += k
            if store.dietTarget > 0, k >= store.dietTarget * 0.88, k <= store.dietTarget * 1.15 { hit += 1 }
        }
        return (days, hit, days > 0 ? Int(sum / Double(days)) : 0)
    }

    private var monthCard: some View {
        let stat = monthStat
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "calendar")
                    .font(.tw(14, .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("饮食月历")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.snappy(duration: 0.2)) { monthOffset = max(0, monthOffset - 1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.tw(11, .bold))
                        .foregroundStyle(monthOffset == 0 ? TWColor.ink3.opacity(0.4) : TWColor.ink2)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .disabled(monthOffset == 0)

                Text(monthTitle)
                    .font(.tw(12, .semibold))
                    .foregroundStyle(TWColor.ink2)
                    .monospacedDigit()

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.snappy(duration: 0.2)) { monthOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.tw(11, .bold))
                        .foregroundStyle(monthOffset == 0 ? TWColor.ink3.opacity(0.4) : TWColor.ink2)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .disabled(monthOffset == 0)
            }

            HStack(spacing: 0) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { w in
                    Text(w)
                        .font(.tw(10.5, .medium))
                        .foregroundStyle(TWColor.ink3)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(Array(monthCells.enumerated()), id: \.offset) { pair in
                    if let d = pair.element {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            detailKey = dayKey(d)
                            showDay = true
                        } label: {
                            dayCell(d)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }

            HStack(spacing: 13) {
                Text("记录 \(stat.days) 天")
                    .font(.tw(11.5, .medium))
                    .foregroundStyle(TWColor.ink3)
                Text("达标 \(stat.hit) 天")
                    .font(.tw(11.5, .semibold))
                    .foregroundStyle(TWColor.mint)
                if stat.days > 0 {
                    Text("均 \(stat.avg) kcal")
                        .font(.tw(11.5, .medium))
                        .foregroundStyle(TWColor.ink3)
                }
                Spacer()
            }

            Text("灰 = 没记，深蓝 = 吃少了，绿 = 刚好，橙 = 超了")
                .font(.tw(10, .regular))
                .foregroundStyle(TWColor.ink3.opacity(0.85))
        }
        .padding(16)
        .twGlass()
    }

    private func dayCell(_ d: Date) -> some View {
        let n = Calendar.current.component(.day, from: d)
        let style = cellStyle(d)
        let isToday = Calendar.current.isDateInToday(d)
        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(style.0)
            if isToday {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(TWColor.purple, lineWidth: 1.4)
            }
            Text("\(n)")
                .font(.tw(11.5, isToday ? .heavy : .medium))
                .foregroundStyle(style.1 ? .white : TWColor.ink3)
        }
        .frame(height: 34)
    }

    private var aiCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showAI = true
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [TWColor.purple, TWColor.mintSoft],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .font(.tw(16, .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("问 AI 教练")
                        .font(.tw(15, .bold))
                        .foregroundStyle(TWColor.ink)
                    Text(AIClient.shared.ready
                         ? "\(AIClient.shared.provider.label) · 结合你今天的数据回答"
                         : "本地引擎可用 · 接上 Key 换成大模型")
                        .font(.tw(11.5))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.tw(12, .bold))
                    .foregroundStyle(TWColor.ink3)
            }
            .padding(14)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .twGlass()
    }

    private var kcalCard: some View {
        HStack(spacing: 18) {
            ZStack {
                ProgressRing(
                    value: store.dietTarget > 0 ? store.dietKcal / store.dietTarget : 0,
                    lineWidth: 12,
                    colors: [TWColor.mint, TWColor.mintSoft, TWColor.blue],
                    size: 136
                )
                VStack(spacing: 0) {
                    Text("\(Int(store.dietKcal))")
                        .font(.tw(31, .heavy))
                        .foregroundStyle(TWColor.ink)
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(.tw(11.5, .semibold))
                        .foregroundStyle(TWColor.ink3)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("还可以吃")
                        .font(.tw(12.5, .semibold))
                        .foregroundStyle(TWColor.ink3)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int(remaining))")
                            .font(.tw(28, .heavy))
                            .foregroundStyle(TWColor.mint)
                        Text("kcal")
                            .font(.tw(12, .medium))
                            .foregroundStyle(TWColor.ink3)
                    }
                }

                Text("目标 \(Int(store.dietTarget)) · 已记录 \(store.meals.count) 餐")
                    .font(.tw(12, .regular))
                    .foregroundStyle(TWColor.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .twGlass()
    }

    private var proteinNeed: Double {
        (store.sessionStart == nil && store.sessions.isEmpty) ? 110 : 130
    }

    /// 碳水、脂肪目标跟着热量目标走：45% 热量给碳水、30% 给脂肪，
    /// 比写死 260g / 70g 更贴每个人的实际摄入。
    private var carbNeed: Double { max(1, store.dietTarget * 0.45 / 4) }
    private var fatNeed: Double { max(1, store.dietTarget * 0.30 / 9) }

    private var proteinLeft: Double { max(0, proteinNeed - store.protein) }

    private var proteinHint: String {
        proteinLeft <= 0 ? "蛋白已达标" : "还差 \(Int(proteinLeft))g 蛋白"
    }

    // MARK: - 缺口补什么

    private var fixPicks: [MealFixPick] {
        let pGap = max(0, store.proteinGoal - store.protein)
        let kGap = max(0, store.dietTarget - store.dietKcal)
        guard pGap > 8 || kGap > 200 else { return [] }

        let eaten = Set(store.meals.map { $0.name })
        let pool = FoodBase.items.filter { f in
            !eaten.contains(f.name) && f.portion > 0 && f.kcal > 0 && f.protein > 0
        }
        // 每 1 kcal 能换到多少蛋白，越高越适合补缺口
        let ranked = pool.sorted { a, b in
            let ra = a.protein * 4 / max(1, a.kcal)
            let rb = b.protein * 4 / max(1, b.kcal)
            if abs(ra - rb) > 0.02 { return ra > rb }
            return a.kcal < b.kcal
        }

        var out: [MealFixPick] = []
        var groups = Set<String>()
        for f in ranked where out.count < 3 {
            if groups.contains(f.group) { continue }
            out.append(MealFixPick(food: f, grams: f.portion))
            groups.insert(f.group)
        }
        return out
    }

    /// 蛋白总量够了但分布不对，肌肉照样不长。
    private var proteinSpreadCard: some View {
        let per = max(18, (store.bodyWeight > 0 ? store.bodyWeight : 70) * 0.3)
        var map: [String: Double] = [:]
        for m in store.meals { map[m.slot ?? "加餐", default: 0] += m.protein }
        let slots = ["早餐", "午餐", "晚餐", "加餐"]

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("蛋白分布")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: "每餐 \(Int(per))g 起", tint: TWColor.purple)
            }

            if store.meals.isEmpty {
                Text("今天还没记吃的。记了之后这里按早、午、晚、加餐分开看。")
                    .font(.tw(11.5))
                    .foregroundStyle(TWColor.ink3)
            } else {
                ForEach(slots, id: \.self) { slot in
                    let g = map[slot] ?? 0
                    HStack(spacing: 10) {
                        Text(slot)
                            .font(.tw(11.5, .semibold))
                            .foregroundStyle(TWColor.ink2)
                            .frame(width: 36, alignment: .leading)
                        ZStack(alignment: .leading) {
                            Capsule().fill(TWColor.ink3.opacity(0.14)).frame(width: 128, height: 6)
                            Capsule()
                                .fill(g >= per ? TWColor.mint : TWColor.amber)
                                .frame(width: max(2, CGFloat(min(g / per, 1.0)) * 128), height: 6)
                        }
                        Text(String(format: "%.0f g", g))
                            .font(.tw(11, .bold))
                            .foregroundStyle(g >= per ? TWColor.mint : TWColor.ink2)
                            .frame(width: 40, alignment: .trailing)
                        Text(g >= per ? "够" : (g > 0 ? "差 \(Int(per - g))" : "没记"))
                            .font(.tw(10))
                            .foregroundStyle(TWColor.ink3)
                        Spacer(minLength: 0)
                    }
                }
                if map["晚餐", default: 0] < per {
                    Text("晚餐还差 \(Int(per - map["晚餐", default: 0]))g 蛋白，睡前补一杯牛奶或一份鸡胸就够。")
                        .font(.tw(10))
                        .foregroundStyle(TWColor.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .twGlass()
    }

    private var fixCard: some View {
        let suggests = fixPicks
        let pGap = max(0, store.proteinGoal - store.protein)
        let kGap = max(0, store.dietTarget - store.dietKcal)
        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: "fork.knife.circle")
                    .font(.tw(14, .semibold))
                    .foregroundStyle(TWColor.amber)
                Text("缺口补什么")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: pGap > 8 ? "差 \(Int(pGap))g 蛋白" : (kGap > 200 ? "差 \(Int(kGap)) kcal" : "差不多够了"),
                          tint: pGap > 8 ? TWColor.coral : TWColor.mint)
            }

            if suggests.isEmpty {
                Text("今天蛋白和热量都到位了，不用再加。")
                    .font(.tw(12.5))
                    .foregroundStyle(TWColor.ink3)
            } else {
                ForEach(suggests) { pick in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pick.food.name)
                                .font(.tw(13.5, .semibold))
                                .foregroundStyle(TWColor.ink)
                                .lineLimit(1)
                            Text("\(Int(pick.grams))g · 蛋白 +\(one(pick.proteinG))g · \(Int(pick.kcalTotal)) kcal")
                                .font(.tw(10.5, .regular))
                                .foregroundStyle(TWColor.ink3)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            store.addMeal(MealEntry(
                                name: pick.food.name,
                                grams: pick.grams,
                                kcal: pick.kcalTotal,
                                protein: pick.proteinG,
                                carb: pick.carbG,
                                fat: pick.fatG,
                                veg: 0,
                                slot: autoSlot,
                                time: Date()
                            ))
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "plus")
                                    .font(.tw(9, .bold))
                                Text("加")
                                    .font(.tw(11, .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                Capsule().fill(LinearGradient(colors: [TWColor.amber, TWColor.coral],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }

                Text("按蛋白密度排的三样，都不是今天已经吃过的。")
                    .font(.tw(10, .regular))
                    .foregroundStyle(TWColor.ink3.opacity(0.85))
            }
        }
        .padding(16)
        .twGlass()
    }

    private func one(_ v: Double) -> String {
        String(format: "%.1f", v)
    }

    /// 「今天还差什么」：按剩余热量和蛋白缺口，从库里挑几样补上
    private var nextBiteCard: some View {
        let leftKcal = store.dietTarget - store.dietKcal
        let leftProtein = max(0, store.proteinGoal - store.protein)
        let leftCarb = max(0, carbNeed - store.carb)
        let picks = FoodBase.items
            .filter { $0.kcal > 0 && $0.portion > 0 && $0.protein / $0.kcal > 0.05 }
            .sorted { ($0.protein / $0.kcal) > ($1.protein / $1.kcal) }
            .prefix(3)
            .map { f -> (String, String, String) in
                let g = f.portion
                let r = g / 100.0
                return (f.name,
                        "\(Int(g))g",
                        "\(Int(f.kcal * r)) kcal · 蛋白 \(String(format: "%.0f", f.protein * r))g")
            }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "fork.knife")
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.mint)
                Text("今天还差什么")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                GlassPill(text: leftKcal > 0 ? "热量还差 \(Int(leftKcal))" : "热量已够",
                          tint: leftKcal > 0 ? TWColor.amber : TWColor.mint)
                GlassPill(text: leftProtein > 0 ? "蛋白还差 \(Int(leftProtein))g" : "蛋白够了",
                          tint: leftProtein > 0 ? TWColor.blue : TWColor.mint)
                if leftCarb > 0 && leftKcal > 0 {
                    GlassPill(text: "碳水差 \(Int(leftCarb))g", tint: TWColor.purple)
                }
                Spacer(minLength: 0)
            }

            if leftProtein <= 0 && leftKcal <= 0 {
                Text("今天的目标已经够了，别再硬塞。")
                    .font(.tw(11))
                    .foregroundStyle(TWColor.ink3)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(picks.enumerated()), id: \.offset) { i, p in
                        HStack(spacing: 10) {
                            Text(p.0)
                                .font(.tw(12.5, .semibold))
                                .foregroundStyle(TWColor.ink)
                            Spacer(minLength: 0)
                            Text(p.1)
                                .font(.tw(11))
                                .foregroundStyle(TWColor.ink3)
                            Text(p.2)
                                .font(.tw(10.5))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 118, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                        if i < picks.count - 1 { Divider().opacity(0.25) }
                    }
                }
                Text("挑 1–2 样就够补上缺口，别三样全吃。")
                    .font(.tw(10))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .padding(16)
        .twGlass()
    }

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("三大营养素")
                    .font(.tw(14.5, .semibold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                GlassPill(text: proteinHint,
                          tint: proteinLeft <= 0 ? TWColor.mint : TWColor.coral)
            }

            macroRow(title: "蛋白质", value: store.protein, target: max(store.proteinGoal, proteinNeed), tint: TWColor.coral, unit: "g")
            macroRow(title: "碳水", value: store.carb, target: carbNeed, tint: TWColor.blue, unit: "g")
            macroRow(title: "脂肪", value: store.fat, target: fatNeed, tint: TWColor.amber, unit: "g")

            macroRatioBar
        }
        .padding(16)
        .twGlass()
    }

    private var macroRatioBar: some View {
        let pKcal = store.protein * 4
        let cKcal = store.carb * 4
        let fKcal = store.fat * 9
        let total = max(pKcal + cKcal + fKcal, 1)

        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Capsule()
                        .fill(TWColor.coral.opacity(0.78))
                        .frame(width: max(geo.size.width * CGFloat(pKcal / total) - 2, 0))
                    Capsule()
                        .fill(TWColor.blue.opacity(0.78))
                        .frame(width: max(geo.size.width * CGFloat(cKcal / total) - 2, 0))
                    Capsule()
                        .fill(TWColor.amber.opacity(0.78))
                }
            }
            .frame(height: 7)

            HStack(spacing: 10) {
                ratioTag("蛋白", pKcal / total, TWColor.coral)
                ratioTag("碳水", cKcal / total, TWColor.blue)
                ratioTag("脂肪", fKcal / total, TWColor.amber)
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 2)
    }

    private func ratioTag(_ name: String, _ ratio: Double, _ tint: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text("\(name) \(Int(ratio * 100))%")
                .font(.tw(10.5, .semibold))
                .foregroundStyle(TWColor.ink3)
        }
    }

    private func macroRow(title: String, value: Double, target: Double, tint: Color, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                Text("\(Int(value)) / \(Int(target)) \(unit)")
                    .font(.tw(12.5, .semibold))
                    .foregroundStyle(value >= target ? TWColor.mint : TWColor.ink3)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(TWColor.glass(0.45))
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.85), tint.opacity(0.55)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(min(value / max(target, 1), 1)))
                }
            }
            .frame(height: 6)
        }
    }

    private var addCard: some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.tw(15, .bold))
                    Text("加一餐 · \(autoSlot)").font(.tw(15, .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $picks, maxSelectionCount: 3, matching: .images, photoLibrary: .shared()) {
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill").font(.tw(17, .bold))
                    Text(analyzing ? "识别中" : "拍照识别").font(.tw(12, .semibold))
                }
                .foregroundStyle(TWColor.purple)
                .frame(width: 92, height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(TWColor.purple.opacity(0.12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(TWColor.purple.opacity(0.22), lineWidth: 0.7)
                        }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.tw(14, .bold))
                    .foregroundStyle(TWColor.blue)
                Text("今天的餐食照片")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Text("\(store.todayPhotos.count) 张 · 只留 40 天")
                    .font(.tw(11))
                    .foregroundStyle(TWColor.ink3)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(store.todayPhotos, id: \.self) { name in
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            previewPhoto = name
                            showPhoto = true
                        } label: {
                            Group {
                                if let img = UIImage(contentsOfFile: store.photoURL(name).path) {
                                    Image(uiImage: img).resizable().scaledToFill()
                                } else {
                                    Rectangle().fill(TWColor.ink3.opacity(0.15))
                                }
                            }
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }

            Text("照片只当影像记录，不参与热量计算。要数营养走上面的「搜食物」或「扫条码」。")
                .font(.tw(10.5))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .twGlass()
    }

    private var searchCard: some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                showFoodSearch = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .font(.tw(16, .bold))
                        .foregroundStyle(TWColor.purple)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("搜食物")
                            .font(.tw(14.5, .bold))
                            .foregroundStyle(TWColor.ink)
                        Text("本地库 + 联网营养表")
                            .font(.tw(10))
                            .foregroundStyle(TWColor.ink3)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(TWColor.purple.opacity(0.10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(TWColor.purple.opacity(0.22), lineWidth: 0.7)
                        }
                }
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                showScanSheet = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.tw(16, .bold))
                        .foregroundStyle(.white)
                    Text("扫条码")
                        .font(.tw(13.5, .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [TWColor.blue, TWColor.purple],
                                             startPoint: .leading, endPoint: .trailing))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var slotSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("今天吃了什么")
                    .font(.tw(14.5, .semibold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    let n = store.copyYesterday()
                    withAnimation(.snappy(duration: 0.2)) { copiedCount = n }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.snappy(duration: 0.2)) { copiedCount = nil }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedCount == nil ? "arrow.uturn.down" : (copiedCount ?? 0) > 0 ? "checkmark" : "xmark")
                            .font(.tw(10, .bold))
                        Text(copiedCount == nil
                             ? "复制昨天"
                             : ((copiedCount ?? 0) > 0 ? "已搬 \(copiedCount ?? 0) 条" : "昨天没记录"))
                            .font(.tw(12, .bold))
                    }
                    .foregroundStyle((copiedCount ?? 0) > 0 ? TWColor.mint : TWColor.purple)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background { Capsule().fill(TWColor.purple.opacity(0.10)) }
                }
                .buttonStyle(.plain)

                if !store.meals.isEmpty {
                    Button("清空") { store.resetToday() }
                        .font(.tw(12.5, .semibold))
                        .foregroundStyle(TWColor.ink3)
                }
            }

            if store.meals.isEmpty {
                Text("还没记录。点「加一餐」或拍张照片，系统会算出热量和蛋白。")
                    .font(.tw(13, .regular))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(slots, id: \.self) { s in
                    let items = meals(in: s)
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(slotTint(s))
                                    .frame(width: 7, height: 7)
                                Text(s)
                                    .font(.tw(13.5, .bold))
                                    .foregroundStyle(TWColor.ink)
                                Text("\(kcal(in: s)) kcal")
                                    .font(.tw(11.5, .semibold))
                                    .foregroundStyle(TWColor.ink3)
                                Spacer(minLength: 0)
                            }
                            ForEach(items) { m in
                                mealRow(m)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .twGlass()
    }

    private func mealRow(_ m: MealEntry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(m.name)
                    .font(.tw(14, .semibold))
                    .foregroundStyle(TWColor.ink)
                Text("\(Int(m.grams))g · 蛋白 \(Int(m.protein))g · 碳 \(Int(m.carb))g · 脂 \(Int(m.fat))g")
                    .font(.tw(11.5, .regular))
                    .foregroundStyle(TWColor.ink3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 4)
            Text("\(Int(m.kcal))")
                .font(.tw(15, .heavy))
                .foregroundStyle(TWColor.ink2)
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.snappy(duration: 0.2)) { store.deleteMeal(id: m.id) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.tw(16))
                    .foregroundStyle(TWColor.ink3.opacity(0.65))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var trendCard: some View {
        TrendChart(
            title: "摄入热量 · 最近 7 天",
            values: recentLogs.map { $0.kcal ?? 0 },
            labels: dayLabels,
            tint: TWColor.mint,
            unit: "kcal",
            goal: store.dietTarget
        )
        .padding(16)
        .twGlass()
    }

    private var weekCard: some View {
        let recorded = recentLogs.filter { ($0.kcal ?? 0) > 0 }
        let avg = recorded.isEmpty
            ? 0
            : recorded.reduce(0.0) { $0 + ($1.kcal ?? 0) } / Double(recorded.count)
        let kcalHit = recorded.filter { abs(($0.kcal ?? 0) - store.dietTarget) <= store.dietTarget * 0.1 }.count
        let proteinHit = recentLogs.filter { ($0.protein ?? 0) >= 110 }.count

        return HStack(spacing: 0) {
            miniStat(title: "平均", value: avg > 0 ? "\(Int(avg))" : "--", unit: "kcal", tint: TWColor.mint)
            divider
            miniStat(title: "有记录", value: "\(recorded.count)", unit: "天", tint: TWColor.blue)
            divider
            miniStat(title: "热量达标", value: "\(kcalHit)", unit: "天", tint: TWColor.purple)
            divider
            miniStat(title: "蛋白达标", value: "\(proteinHit)", unit: "天", tint: TWColor.coral)
        }
        .padding(.vertical, 14)
        .twGlass(radius: 18)
    }

    private var divider: some View {
        Rectangle()
            .fill(TWColor.ink3.opacity(0.16))
            .frame(width: 0.8, height: 30)
    }

    private func miniStat(title: String, value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.tw(11, .semibold))
                .foregroundStyle(TWColor.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.tw(19, .heavy))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.tw(10.5, .medium))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct FoodPicker: View {
    var defaultSlot: String = "午餐"
    var onPick: (MealEntry) -> Void
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double = 150
    @State private var selected: FoodPreset = foodPresets[0]
    @State private var slot: String = ""
    @State private var showCustom = false

    private let slots = ["早餐", "午餐", "晚餐", "加餐"]
    private var activeSlot: String { slot.isEmpty ? defaultSlot : slot }

    /// 最近吃过（含今天和近 7 天归档），点一下按原克数再记一次
    private var recents: [MealEntry] { store.recentMeals(limit: 10) }

    private var customPresets: [FoodPreset] {
        store.customFoods.map { c in
            FoodPreset(name: c.name, emoji: "🍽️",
                       kcalPer100: c.kcalPer100, proteinPer100: c.proteinPer100,
                       carbPer100: c.carbPer100, fatPer100: c.fatPer100, vegPer100: 0)
        }
    }

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 14) {
                Capsule()
                    .fill(TWColor.ink3.opacity(0.4))
                    .frame(width: 34, height: 4)
                    .padding(.top, 8)

                HStack(spacing: 8) {
                    Text("加一餐")
                        .font(.tw(19, .heavy))
                        .foregroundStyle(TWColor.ink)
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        showCustom = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.tw(11, .bold))
                            Text("自定义")
                                .font(.tw(12.5, .bold))
                        }
                        .foregroundStyle(TWColor.purple)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background {
                            Capsule().fill(TWColor.purple.opacity(0.12))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)

                HStack(spacing: 7) {
                    ForEach(slots, id: \.self) { s in
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            withAnimation(.snappy(duration: 0.2)) { slot = s }
                        } label: {
                            Text(s)
                                .font(.tw(13, activeSlot == s ? .bold : .medium))
                                .foregroundStyle(activeSlot == s ? .white : TWColor.ink2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(activeSlot == s
                                              ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                                              : AnyShapeStyle(TWColor.glass(0.42)))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)

                if !recents.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("最近吃过")
                                .font(.tw(12, .bold))
                                .foregroundStyle(TWColor.ink3)
                            Spacer(minLength: 0)
                            Text("点一下按原分量直接记")
                                .font(.tw(10.5))
                                .foregroundStyle(TWColor.ink3)
                        }
                        .padding(.horizontal, 18)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recents) { m in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                        onPick(MealEntry(name: m.name, grams: m.grams, kcal: m.kcal,
                                                         protein: m.protein, carb: m.carb,
                                                         fat: m.fat, veg: m.veg,
                                                         slot: activeSlot, time: Date()))
                                        dismiss()
                                    } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(m.name)
                                                .font(.tw(12.5, .semibold))
                                                .foregroundStyle(TWColor.ink)
                                                .lineLimit(1)
                                            Text("\(Int(m.kcal)) kcal · \(Int(m.grams))g")
                                                .font(.tw(10))
                                                .foregroundStyle(TWColor.ink3)
                                        }
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: 170, alignment: .leading)
                                        .background {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(TWColor.glass(0.5))
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 18)
                        }
                    }
                }

                ScrollView {
                    VStack(spacing: 8) {
                        if !customPresets.isEmpty {
                            HStack {
                                Text("我的常吃")
                                    .font(.tw(12, .bold))
                                    .foregroundStyle(TWColor.ink3)
                                Spacer()
                            }
                            .padding(.horizontal, 4)

                            ForEach(customPresets) { f in
                                presetRow(f)
                            }

                            HStack {
                                Text("常见食物")
                                    .font(.tw(12, .bold))
                                    .foregroundStyle(TWColor.ink3)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                        }

                        ForEach(foodPresets) { f in
                            presetRow(f)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 6) {
                    HStack {
                        Text("分量")
                            .font(.tw(13, .semibold))
                            .foregroundStyle(TWColor.ink2)
                        Spacer()
                        Text("\(Int(grams)) g")
                            .font(.tw(15, .heavy))
                            .foregroundStyle(TWColor.purple)
                    }
                    Slider(value: $grams, in: 30...500, step: 5)
                        .tint(TWColor.purple)
                }
                .padding(.horizontal, 18)

                Button {
                    let g = grams / 100
                    onPick(MealEntry(
                        name: selected.name,
                        grams: grams,
                        kcal: selected.kcalPer100 * g,
                        protein: selected.proteinPer100 * g,
                        carb: selected.carbPer100 * g,
                        fat: selected.fatPer100 * g,
                        veg: selected.vegPer100 * g,
                        slot: activeSlot,
                        time: Date()
                    ))
                    dismiss()
                } label: {
                    Text("记入\(activeSlot)")
                        .font(.tw(16, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.bottom, 22)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            if slot.isEmpty { slot = defaultSlot }
        }
        .sheet(isPresented: $showCustom) {
            CustomFoodSheet()
                .presentationDetents([.height(420)])
                .presentationCornerRadius(26)
        }
    }

    private func presetRow(_ f: FoodPreset) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { selected = f }
        } label: {
            HStack {
                Text(f.emoji).font(.tw(19))
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name)
                        .font(.tw(14.5, .semibold))
                        .foregroundStyle(TWColor.ink)
                    Text("每 100g · \(Int(f.kcalPer100)) kcal · 蛋白 \(String(format: "%.1f", f.proteinPer100))g")
                        .font(.tw(11.5, .regular))
                        .foregroundStyle(TWColor.ink3)
                }
                Spacer()
                if selected.name == f.name {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(TWColor.purple)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(selected.name == f.name ? TWColor.glass(0.82) : TWColor.glass(0.34))
            }
        }
        .buttonStyle(.plain)
    }
}

struct ShotResultSheet: View {
    var hits: [FoodHit]
    var defaultSlot: String = "午餐"
    /// 这一轮相机实际读到的字，认不出时摆出来给用户看
    var words: [String] = []
    /// 引擎这一步看到的字、分组和分数（调试台）
    var diag: [String] = []
    var onGoSearch: (() -> Void)? = nil
    var onGoScan: (() -> Void)? = nil
    var onAdd: (FoodHit) -> Void
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []
    /// 每条结果的份量可以逐 20g 调，小袋 20g 和大袋 100g 差别是五倍热量
    @State private var gramsOverride: [UUID: Double] = [:]
    /// 认不出时直接在这儿打字，边打边从库里出候选
    @State private var manualQuery = ""
    @FocusState private var manualFocus: Bool
    @State private var showAI = false
    @State private var savedToast = false
    @State private var showDiag = false
    /// 正在给哪条结果扫码补克数
    @State private var scanTarget: FoodHit?
    /// 正在纠正哪条结果（认错了就地改，改完写进学习表）
    @State private var fixTarget: FoodHit?
    @State private var fixQuery = ""
    /// 纠正过的结果留在这，原 hits 是外部传进来不可变的
    @State private var fixedHits: [FoodHit] = []

    private let slots = ["早餐", "午餐", "晚餐", "加餐"]
    @State private var slot: String = ""

    private var activeSlot: String { slot.isEmpty ? defaultSlot : slot }

    /// 认不出来时的三条正经出路，比让人重拍一张强
    private var recentMeals: [MealEntry] { Array(store.meals.reversed().prefix(6)) }

    // MARK: - 结果行（份量可调）

    private func gramsOf(_ h: FoodHit) -> Double { gramsOverride[h.id] ?? h.grams }
    private func rateOf(_ h: FoodHit) -> Double { max(0.1, gramsOf(h) / max(1, h.grams)) }

    /// 纠正过就用改后的，没改过用引擎给的
    private var shownHits: [FoodHit] { fixedHits.isEmpty ? hits : fixedHits }

    /// 就地改对这一条，并把「读到的字 → 对的食物」记进学习表。
    /// 库再全也追不上每个人的零食柜，用户改一次比调十个阈值管用。
    private func applyFix(_ food: LocalFood, for h: FoodHit) {
        let g = gramsOf(h)
        let r = g / max(1, food.portion)
        let fixed = FoodHit(name: food.name, grams: g,
                            kcal: food.kcal * r, protein: food.protein * r,
                            carb: food.carb * r, fat: food.fat * r,
                            veg: 0,
                            confidence: 1.0, source: "你改过的",
                            keyword: h.keyword)

        var list = shownHits
        if let idx = list.firstIndex(where: { $0.id == h.id }) { list[idx] = fixed }
        fixedHits = list

        // 选中状态和份量跟着那条结果走
        if selected.contains(h.id) {
            selected.remove(h.id)
            selected.insert(fixed.id)
        }
        if let gv = gramsOverride[h.id] {
            gramsOverride.removeValue(forKey: h.id)
            gramsOverride[fixed.id] = gv
        }

        let word = h.keyword.isEmpty ? h.name : h.keyword
        FoodLearn.remember(word: word, food: food.name)
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.snappy(duration: 0.2)) {
            fixTarget = nil
            fixQuery = ""
        }
    }

    /// 按用户调过的份量重算一条
    private func scaled(_ h: FoodHit) -> FoodHit {
        let r = rateOf(h)
        return FoodHit(name: h.name, grams: gramsOf(h),
                       kcal: h.kcal * r, protein: h.protein * r,
                       carb: h.carb * r, fat: h.fat * r,
                       veg: h.veg, confidence: h.confidence,
                       source: h.source, keyword: h.keyword)
    }

    private func resultRow(_ h: FoodHit) -> some View {
        let on = selected.contains(h.id)
        let g = gramsOf(h)
        let r = rateOf(h)
        return VStack(spacing: 0) {
            Button {
                if selected.contains(h.id) { selected.remove(h.id) }
                else { selected.insert(h.id) }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(h.name)
                            .font(.tw(15, .semibold))
                            .foregroundStyle(TWColor.ink)
                        Text("\(Int(g))g · \(Int(h.kcal * r)) kcal")
                            .font(.tw(12))
                            .foregroundStyle(TWColor.ink2)
                        Text("蛋白 \(Int(h.protein * r)) · 碳水 \(Int(h.carb * r)) · 脂肪 \(Int(h.fat * r)) g")
                            .font(.tw(11))
                            .foregroundStyle(TWColor.ink3)
                        Text(h.source)
                            .font(.tw(10, .semibold))
                            .foregroundStyle(h.source.contains("读包装") || h.source.contains("读到品牌")
                                             ? TWColor.mint : TWColor.ink3)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .font(.tw(20, .semibold))
                        .foregroundStyle(TWColor.purple)
                }
                .padding(14)
                .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)

            if on {
                HStack(spacing: 8) {
                    Text("份量")
                        .font(.tw(11.5, .bold))
                        .foregroundStyle(TWColor.ink3)
                    gramsStep("minus") { bump(h, -20) }
                    Text("\(Int(g))g")
                        .font(.tw(13, .bold))
                        .foregroundStyle(TWColor.ink)
                        .frame(minWidth: 46)
                    gramsStep("plus") { bump(h, 20) }
                    if gramsOf(h) != h.grams {
                        Button("还原") { gramsOverride[h.id] = nil }
                            .font(.tw(11, .bold))
                            .foregroundStyle(TWColor.ink3)
                            .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)

                HStack(spacing: 8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        scanTarget = h
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.tw(11, .bold))
                            Text("扫码补克数")
                                .font(.tw(11.5, .bold))
                        }
                        .foregroundStyle(TWColor.blue)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background { Capsule().fill(TWColor.blue.opacity(0.12)) }
                    }
                    .buttonStyle(.plain)
                    Text("认出品牌却不知道这包多少克，扫包装条码读净含量")
                        .font(.tw(10.5))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)

                HStack(spacing: 8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.snappy(duration: 0.2)) {
                            fixTarget = (fixTarget?.id == h.id) ? nil : h
                            fixQuery = ""
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.tw(11, .bold))
                            Text(fixTarget?.id == h.id ? "收起" : "认错了？换一个")
                                .font(.tw(11.5, .bold))
                        }
                        .foregroundStyle(TWColor.coral)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background { Capsule().fill(TWColor.coral.opacity(0.12)) }
                    }
                    .buttonStyle(.plain)

                    Text("改过之后会记住，下次读到同样的字直接命中")
                        .font(.tw(10.5))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)

                if fixTarget?.id == h.id {
                    fixPanel(for: h)
                        .padding(.horizontal, 14)
                }

                Spacer()
                    .frame(height: 12)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(TWColor.glass(on ? 0.85 : 0.42))
        }
    }

    /// 认错了就地改：搜到哪个就换哪个，顺着把「读到的字 → 食物」写进学习表
    private func fixPanel(for h: FoodHit) -> some View {
        let q = fixQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let cands = q.isEmpty ? [] : FoodBase.search(q, limit: 5)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.tw(11, .semibold))
                    .foregroundStyle(TWColor.ink3)
                TextField("正确是哪个食物？", text: $fixQuery)
                    .font(.tw(12.5))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(TWColor.glass(0.42))
            }

            if cands.isEmpty {
                Text(q.isEmpty ? "输入名字，从库里挑一个正确的" : "库里没有匹配，换个说法再试")
                    .font(.tw(10.5))
                    .foregroundStyle(TWColor.ink3)
            } else {
                ForEach(cands) { f in
                    Button {
                        applyFix(f, for: h)
                    } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.name)
                                    .font(.tw(12.5, .semibold))
                                    .foregroundStyle(TWColor.ink)
                                Text("\(Int(f.kcal)) kcal / \(Int(f.portion))g · 蛋白 \(Int(f.protein))g")
                                    .font(.tw(10.5))
                                    .foregroundStyle(TWColor.ink3)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.tw(14, .semibold))
                                .foregroundStyle(TWColor.mint)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(TWColor.glass(0.34))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 4)
    }

    /// 识别调试台：引擎看到的原始字、分组位置、命中分数都摆出来，
    /// 阈值调不准的时候，只有真照片能给出答案
    private var diagPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.snappy(duration: 0.2)) { showDiag.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "stethoscope")
                        .font(.tw(11, .semibold))
                    Text("识别调试台")
                        .font(.tw(11.5, .bold))
                    Spacer(minLength: 0)
                    Image(systemName: showDiag ? "chevron.up" : "chevron.down")
                        .font(.tw(9, .bold))
                }
                .foregroundStyle(TWColor.ink3)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)

            if showDiag {
                Text(diag.isEmpty ? "这一轮没有过程数据" : diag.joined(separator: "\n"))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(TWColor.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(TWColor.blue.opacity(0.06))
                    }
            }
        }
    }

    // MARK: - 补充一句就认

    /// 认不出时，用户补一句「乐事原味薯片 70g」——先剥规格，再按字匹配，
    /// 点一下就变成结果里的一条（可继续补），不再是一条就关窗。
    private var manualEntry: some View {
        let raw = manualQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let q = FoodRank.parse(raw)
        let scored = raw.isEmpty ? [] : FoodRank.rank(raw, limit: 6)

        return VStack(alignment: .leading, spacing: 9) {
            Text("认不出就补一句")
                .font(.tw(11.5, .bold))
                .foregroundStyle(TWColor.ink3)

            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.tw(12, .semibold))
                    .foregroundStyle(TWColor.ink3)
                TextField("乐事原味薯片 70g、蜜雪柠檬水 500ml", text: $manualQuery)
                    .font(.tw(13.5))
                    .focused($manualFocus)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !raw.isEmpty {
                    Button {
                        manualQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.tw(12))
                            .foregroundStyle(TWColor.ink3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(TWColor.glass(0.55))
            }

            if !raw.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.tw(10, .semibold))
                        .foregroundStyle(TWColor.purple)
                    Text(parseLine(q))
                        .font(.tw(10.5))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                if scored.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("库里没有这一款")
                            .font(.tw(11.5, .semibold))
                            .foregroundStyle(TWColor.coral)
                        Text("先按同类估算记上（会标成估算），或者退出去扫包装条码拿厂商数据。")
                            .font(.tw(10.5))
                            .foregroundStyle(TWColor.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            addEstimate(q)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "wand.and.stars")
                                    .font(.tw(11, .bold))
                                Text("按同类估算加入")
                                    .font(.tw(11.5, .bold))
                            }
                            .foregroundStyle(TWColor.amber)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background { Capsule().fill(TWColor.amber.opacity(0.13)) }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ForEach(scored, id: \.food.id) { fs in
                        Button {
                            addFromFood(fs.food, query: q)
                        } label: {
                            HStack(spacing: 9) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fs.food.name)
                                        .font(.tw(13, .semibold))
                                        .foregroundStyle(TWColor.ink)
                                    Text("每份 \(Int(fs.food.portion))g · \(Int(fs.food.kcal)) kcal · 蛋白 \(Int(fs.food.protein)) · 碳水 \(Int(fs.food.carb)) · 脂肪 \(Int(fs.food.fat))")
                                        .font(.tw(10))
                                        .foregroundStyle(TWColor.ink3)
                                        .lineLimit(1)
                                    Text(fs.reason)
                                        .font(.tw(9.5))
                                        .foregroundStyle(TWColor.mint)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "plus.circle.fill")
                                    .font(.tw(15, .bold))
                                    .foregroundStyle(TWColor.purple)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(TWColor.purple.opacity(0.07))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(TWColor.glass(0.4))
        }
    }

    private func parseLine(_ q: FoodRank.Query) -> String {
        var parts: [String] = ["理解为「\(q.name)」"]
        if let g = q.grams { parts.append("\(Int(g))g") }
        if q.packs > 1 { parts.append("×\(q.packs) 份") }
        return parts.joined(separator: " · ")
    }

    /// 选中的库内条目 → 直接进结果列表并默认选中
    private func addFromFood(_ f: LocalFood, query: FoodRank.Query) {
        let g = query.grams ?? (f.portion * Double(max(1, query.packs)))
        let r = g / 100
        let hit = FoodHit(name: f.name, grams: g,
                          kcal: f.kcal * r, protein: f.protein * r,
                          carb: f.carb * r, fat: f.fat * r,
                          veg: 0, confidence: 1.0,
                          source: "你补的名字", keyword: query.name)
        appendHit(hit)
        FoodLearn.remember(word: query.name, food: f.name)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        manualQuery = ""
        manualFocus = false
    }

    /// 库里没有就按同类估一条，来源写清楚是估算，别冒充实测
    private func addEstimate(_ q: FoodRank.Query) {
        let g = q.grams ?? 100
        let r = g / 100
        let n = q.name
        var kcal = 150.0, p = 8.0, c = 18.0, f = 5.0
        if ["饮", "茶", "水", "汁", "奶", "咖啡", "可乐", "雪碧", "柠檬"].contains(where: { n.contains($0) }) {
            kcal = 45; p = 0.5; c = 10; f = 0.5
        } else if ["薯", "片", "条", "脆", "饼", "糖", "巧克力", "锅巴", "辣条", "果冻"].contains(where: { n.contains($0) }) {
            kcal = 500; p = 6; c = 55; f = 30
        } else if ["面", "饭", "包", "粉", "粥", "饺"].contains(where: { n.contains($0) }) {
            kcal = 200; p = 5; c = 35; f = 4
        }
        let hit = FoodHit(name: n, grams: g, kcal: kcal * r,
                          protein: p * r, carb: c * r, fat: f * r,
                          veg: 0, confidence: 0.4, source: "同类估算 · 回头记得改",
                          keyword: n)
        appendHit(hit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        manualQuery = ""
        manualFocus = false
    }

    /// 追加进结果列表；同名只加份量，不堆两行
    private func appendHit(_ hit: FoodHit) {
        var list = shownHits
        if let i = list.firstIndex(where: { $0.name == hit.name }) {
            var old = list[i]
            old.grams += hit.grams
            old.kcal += hit.kcal
            old.protein += hit.protein
            old.carb += hit.carb
            old.fat += hit.fat
            list[i] = old
            fixedHits = list
            selected.insert(old.id)
        } else {
            list.append(hit)
            fixedHits = list
            selected.insert(hit.id)
        }
    }

    // MARK: - 读到了却没认出来的字

    /// OCR 读到的字里有，但没落成任何一条结果的，拎出来给用户点
    private var unreadWords: [String] {
        guard !words.isEmpty else { return [] }
        var seen = Set<String>()
        var out: [String] = []
        for w in words {
            let c = FoodRank.clean(w)
            guard c.count >= 2, c.count <= 12 else { continue }
            guard seen.insert(c).inserted else { continue }
            if shownHits.contains(where: {
                $0.name.contains(c) || c.contains($0.name) || $0.keyword.contains(c)
            }) { continue }
            out.append(c)
        }
        return Array(out.prefix(4))
    }

    private var unreadCard: some View {
        let list = unreadWords
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "questionmark.bubble")
                    .font(.tw(11, .semibold))
                    .foregroundStyle(TWColor.amber)
                Text("这些字读到了，但没对上号")
                    .font(.tw(11.5, .bold))
                    .foregroundStyle(TWColor.ink2)
                Spacer(minLength: 0)
            }
            Text("点一个填进下面的框，出候选后再选是哪一款")
                .font(.tw(10))
                .foregroundStyle(TWColor.ink3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(list, id: \.self) { w in
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            manualQuery = w
                            manualFocus = true
                        } label: {
                            Text(w)
                                .font(.tw(11.5, .semibold))
                                .foregroundStyle(TWColor.ink2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background { Capsule().fill(TWColor.glass(0.55)) }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(TWColor.amber.opacity(0.06))
        }
    }

    private func bump(_ h: FoodHit, _ delta: Double) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        gramsOverride[h.id] = min(800, max(5, gramsOf(h) + delta))
    }

    private func gramsStep(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.tw(11, .bold))
                .foregroundStyle(TWColor.purple)
                .frame(width: 32, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(TWColor.glass(0.6))
                }
        }
        .buttonStyle(.plain)
    }

    private var emptyActions: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("认不出来的时候")
                .font(.tw(11.5, .bold))
                .foregroundStyle(TWColor.ink3)

            if let onGoScan {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    dismiss()
                    onGoScan()
                } label: {
                    quickRow("barcode.viewfinder", "扫包装上的条码",
                             "条码直接对应厂商申报的营养表，最准", TWColor.mint)
                }
                .buttonStyle(.plain)
            }

            if let onGoSearch {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    dismiss()
                    onGoSearch()
                } label: {
                    quickRow("magnifyingglass", "按名字搜",
                             "库里已经有魔芋爽、咪咪虾条、卫龙、蜜雪冰城这些", TWColor.blue)
                }
                .buttonStyle(.plain)
            }

            if !recentMeals.isEmpty {
                Text("最近吃过的")
                    .font(.tw(11.5, .bold))
                    .foregroundStyle(TWColor.ink3)
                    .padding(.top, 2)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(recentMeals) { m in
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onAdd(FoodHit(name: m.name, grams: m.grams, kcal: m.kcal,
                                          protein: m.protein, carb: m.carb, fat: m.fat,
                                          veg: m.veg, confidence: 1.0, source: "上次吃过"))
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.name)
                                    .font(.tw(12.5, .semibold))
                                    .foregroundStyle(TWColor.ink)
                                    .lineLimit(1)
                                Text("\(Int(m.grams))g · \(Int(m.kcal)) kcal")
                                    .font(.tw(10))
                                    .foregroundStyle(TWColor.ink3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(TWColor.glass(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TWColor.glass(0.35))
        }
    }

    private func quickRow(_ icon: String, _ title: String, _ sub: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.tw(14, .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background { RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.13)) }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.ink)
                Text(sub)
                    .font(.tw(10))
                    .foregroundStyle(TWColor.ink3)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.tw(10, .bold))
                .foregroundStyle(TWColor.ink3)
        }
    }


    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 0) {
                Capsule()
                    .fill(TWColor.ink3.opacity(0.4))
                    .frame(width: 34, height: 4)
                    .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("识别结果")
                            .font(.tw(20, .heavy))
                            .foregroundStyle(TWColor.ink)

                        Text(hits.isEmpty
                             ? "没看出明显食物，换个角度、把餐盘放正再拍一次"
                             : "共 \(hits.count) 项，勾选要记入的")
                            .font(.tw(13))
                            .foregroundStyle(TWColor.ink3)

                        Text("拍照只能按颜色估个大概，别当准数。要精确就到「搜食物」按名称查，或「扫条码」读包装上厂商申报的营养表。")
                            .font(.tw(11.5))
                            .foregroundStyle(TWColor.amber)
                            .lineSpacing(2.5)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(TWColor.amber.opacity(0.10))
                            }

                        if hits.isEmpty {
                            if !words.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("相机读到了这些字，只是库里没对上")
                                        .font(.tw(11.5, .bold))
                                        .foregroundStyle(TWColor.ink3)
                                    Text(words.prefix(6).joined(separator: " · "))
                                        .font(.tw(11.5))
                                        .foregroundStyle(TWColor.ink2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(TWColor.blue.opacity(0.08))
                                }
                            }
                            emptyActions
                        }

                        HStack(spacing: 7) {
                            ForEach(slots, id: \.self) { s in
                                Button {
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    withAnimation(.snappy(duration: 0.2)) { slot = s }
                                } label: {
                                    Text(s)
                                        .font(.tw(13, activeSlot == s ? .bold : .medium))
                                        .foregroundStyle(activeSlot == s ? .white : TWColor.ink2)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background {
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .fill(activeSlot == s
                                                      ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                                      : AnyShapeStyle(TWColor.glass(0.42)))
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !unreadWords.isEmpty {
                            unreadCard
                        }

                        ForEach(shownHits) { h in
                            resultRow(h)
                        }

                        manualEntry
                            .padding(.top, 2)

                        diagPanel
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                }

                if !shownHits.isEmpty {
                    HStack(spacing: 6) {
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            let chosen = shownHits.filter { selected.contains($0.id) }
                            store.saveAsCustom((chosen.isEmpty ? shownHits : chosen).map { scaled($0) })
                            withAnimation(.snappy(duration: 0.2)) { savedToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                withAnimation(.snappy(duration: 0.2)) { savedToast = false }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: savedToast ? "checkmark.circle.fill" : "star")
                                    .font(.tw(12, .bold))
                                Text(savedToast ? "已存进我的常吃" : "存进我的常吃")
                                    .font(.tw(12.5, .bold))
                            }
                            .foregroundStyle(savedToast ? TWColor.mint : TWColor.ink2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                Capsule().fill(TWColor.glass(0.55))
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                }

                HStack(spacing: 9) {
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        showAI = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.tw(13, .bold))
                            Text("问 AI")
                                .font(.tw(14, .bold))
                        }
                        .foregroundStyle(TWColor.purple)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(TWColor.glass(0.66))
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        let picked = shownHits.filter { selected.contains($0.id) }
                        if picked.isEmpty {
                            dismiss()
                            onGoSearch?()
                            return
                        }
                        for h in picked {
                            if !h.keyword.isEmpty { FoodLearn.remember(word: h.keyword, food: h.name) }
                            onAdd(scaled(h))
                        }
                        dismiss()
                    } label: {
                        let pickedCount = shownHits.filter { selected.contains($0.id) }.count
                        Text(shownHits.isEmpty ? "去搜食物"
                             : (pickedCount > 1 ? "记入\(activeSlot) · \(pickedCount) 条" : "记入\(activeSlot)"))
                            .font(.tw(16, .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            selected = Set(hits.map { $0.id })
            if slot.isEmpty { slot = defaultSlot }
        }
        .sheet(isPresented: $showAI) {
            AIChatSheet(seed: aiSeed)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(item: $scanTarget) { h in
            BarcodeScanSheet(slot: activeSlot, gramsOnly: { p in
                let g = p.defaultGrams > 0 ? p.defaultGrams : 100
                gramsOverride[h.id] = g
            })
            .environmentObject(store)
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
    }

    /// 把识别结果拼成一句开场白，AI 能直接接着聊
    private var aiSeed: String {
        guard !hits.isEmpty else { return "我刚拍了一餐，没认出具体食物，帮我估个热量搭配。" }
        let list = hits.map { "\($0.name)\(Int($0.grams))g（\(Int($0.kcal)) kcal，蛋白 \(Int($0.protein))g）" }
            .joined(separator: "、")
        let kcal = Int(hits.reduce(0) { $0 + $1.kcal })
        return "我刚拍了这一餐：\(list)。合计约 \(kcal) kcal。这顿搭得怎么样，还差什么？"
    }
}

struct FoodPreset: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var emoji: String
    var kcalPer100: Double
    var proteinPer100: Double
    var carbPer100: Double
    var fatPer100: Double
    var vegPer100: Double
}

let foodPresets: [FoodPreset] = [
    FoodPreset(name: "白米饭", emoji: "🍚", kcalPer100: 116, proteinPer100: 2.6, carbPer100: 25.9, fatPer100: 0.3, vegPer100: 0),
    FoodPreset(name: "鸡胸肉", emoji: "🍗", kcalPer100: 133, proteinPer100: 19.4, carbPer100: 2.5, fatPer100: 5.0, vegPer100: 0),
    FoodPreset(name: "西兰花", emoji: "🥦", kcalPer100: 34, proteinPer100: 2.8, carbPer100: 6.6, fatPer100: 0.4, vegPer100: 100),
    FoodPreset(name: "全麦面包", emoji: "🍞", kcalPer100: 246, proteinPer100: 8.5, carbPer100: 45.0, fatPer100: 3.3, vegPer100: 0),
    FoodPreset(name: "鸡蛋", emoji: "🥚", kcalPer100: 144, proteinPer100: 13.3, carbPer100: 2.8, fatPer100: 8.8, vegPer100: 0),
    FoodPreset(name: "牛油果", emoji: "🥑", kcalPer100: 160, proteinPer100: 2.0, carbPer100: 8.5, fatPer100: 14.7, vegPer100: 0),
    FoodPreset(name: "三文鱼", emoji: "🐟", kcalPer100: 208, proteinPer100: 20.0, carbPer100: 0, fatPer100: 13.0, vegPer100: 0),
    FoodPreset(name: "红薯", emoji: "🍠", kcalPer100: 86, proteinPer100: 1.6, carbPer100: 20.1, fatPer100: 0.1, vegPer100: 0)
]

/// 点饮食月历里某一天弹出来的明细
struct DietDaySheet: View {
    let key: String
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    private var items: [MealEntry] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        if key == f.string(from: Date()) { return store.meals }
        return store.mealHistory[key] ?? []
    }

    private var total: Int { Int(items.reduce(0) { $0 + $1.kcal }) }

    private var titleText: String {
        let p = key.split(separator: "-")
        guard p.count == 3 else { return key }
        return "\(p[1]) 月 \(p[2]) 日"
    }

    private var groups: [(String, [MealEntry])] {
        ["早餐", "午餐", "晚餐", "加餐"].compactMap { s -> (String, [MealEntry])? in
            let list = items.filter { ($0.slot ?? "加餐") == s }
            return list.isEmpty ? nil : (s, list)
        }
    }

    private func tint(_ s: String) -> Color {
        switch s {
        case "早餐": return TWColor.amber
        case "午餐": return TWColor.mint
        case "晚餐": return TWColor.purple
        default:     return TWColor.blue
        }
    }

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(titleText)
                            .font(.tw(19, .heavy))
                            .foregroundStyle(TWColor.ink)
                        Text(items.isEmpty ? "这天没记东西" : "\(items.count) 条 · 共 \(total) kcal")
                            .font(.tw(11.5, .regular))
                            .foregroundStyle(TWColor.ink3)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.tw(12, .bold))
                            .foregroundStyle(TWColor.ink2)
                            .frame(width: 34, height: 34)
                            .background { Circle().fill(TWColor.ink3.opacity(0.1)) }
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(groups.enumerated()), id: \.offset) { pair in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Circle().fill(tint(pair.element.0)).frame(width: 7, height: 7)
                                    Text(pair.element.0)
                                        .font(.tw(12, .bold))
                                        .foregroundStyle(TWColor.ink2)
                                    Spacer()
                                    Text("\(Int(pair.element.1.reduce(0) { $0 + $1.kcal })) kcal")
                                        .font(.tw(11, .medium))
                                        .foregroundStyle(TWColor.ink3)
                                }
                                ForEach(pair.element.1) { m in
                                    HStack {
                                        Text(m.name)
                                            .font(.tw(13, .medium))
                                            .foregroundStyle(TWColor.ink)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(String(format: "%.0fg", m.grams))
                                            .font(.tw(10.5, .regular))
                                            .foregroundStyle(TWColor.ink3)
                                        Text("\(Int(m.kcal)) kcal")
                                            .font(.tw(11.5, .semibold))
                                            .foregroundStyle(TWColor.ink2)
                                    }
                                    .padding(.vertical, 5)
                                }
                            }
                            .padding(13)
                            .twGlass(radius: 16)
                        }

                        if items.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "fork.knife")
                                    .font(.tw(24, .regular))
                                    .foregroundStyle(TWColor.ink3)
                                Text("这天没有记录")
                                    .font(.tw(13, .medium))
                                    .foregroundStyle(TWColor.ink3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(18)
        }
    }
}

/// 缺口推荐里的一条：食物 + 建议份量
struct MealFixPick: Identifiable {
    let food: LocalFood
    let grams: Double

    var id: String { food.name + "\(grams)" }
    var kcalTotal: Double { food.kcal * grams / 100 }
    var proteinG: Double { food.protein * grams / 100 }
    var carbG: Double { food.carb * grams / 100 }
    var fatG: Double { food.fat * grams / 100 }
}

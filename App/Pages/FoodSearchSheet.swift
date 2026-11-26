import SwiftUI
import UIKit

/// 一条可加入餐食的候选
struct FoodPick: Identifiable {
    var id = UUID()
    var name: String
    var brand: String = ""
    var group: String = ""
    var kcal100: Double = 0
    var protein100: Double = 0
    var carb100: Double = 0
    var fat100: Double = 0
    var fiber100: Double = 0
    var defaultGrams: Double = 100
    var source: String = "本地库"
    var ingredients: String = ""
    var imageURL: String = ""
}

/// 食物搜索：本地精选库即时出结果，联网（Open Food Facts）补包装食品的官方营养成分与配料表。
struct FoodSearchSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    let defaultSlot: String

    @State private var query = ""
    @State private var local: [LocalFood] = []
    @State private var remote: [RemoteFood] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var pick: FoodPick?
    @State private var showScan = false
    @State private var debounce: DispatchWorkItem?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    searchBar
                    scanEntry

                    if !local.isEmpty {
                        sectionTitle("本地精选 · \(local.count)")
                        VStack(spacing: 0) {
                            ForEach(Array(local.enumerated()), id: \.element.id) { pair in
                                localRow(pair.element)
                                if pair.offset < local.count - 1 {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(TWColor.glass(0.6))
                        }
                    }

                    if loading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在查 Open Food Facts…")
                                .font(.tw(12.5))
                                .foregroundStyle(TWColor.ink3)
                        }
                        .padding(.vertical, 10)
                    }

                    if let e = errorText {
                        HStack(spacing: 7) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(TWColor.amber)
                            Text(e)
                                .font(.tw(12))
                                .foregroundStyle(TWColor.ink2)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(TWColor.amber.opacity(0.10))
                        }
                    }

                    if !remote.isEmpty {
                        sectionTitle("联网 · Open Food Facts · \(remote.count)")
                        VStack(spacing: 0) {
                            ForEach(Array(remote.enumerated()), id: \.element.id) { pair in
                                remoteRow(pair.element)
                                if pair.offset < remote.count - 1 {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(TWColor.glass(0.6))
                        }
                    }

                    if query.isEmpty {
                        tipCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 26)
            }
            .background { AuroraBG() }
            .navigationTitle("找食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(item: $pick) { p in
                GramSheet(pick: p, slot: defaultSlot) { entry in
                    store.addMeal(entry)
                    dismiss()
                }
                .presentationDetents([.large])
                .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showScan) {
                BarcodeScanSheet(slot: defaultSlot)
                    .environmentObject(store)
                    .presentationDetents([.large])
                    .presentationCornerRadius(28)
            }
            .onAppear {
                local = FoodBase.search("", limit: 24)
            }
            .onChange(of: query) { _, newValue in
                scheduleSearch(newValue)
            }
        }
    }

    // MARK: - 组件

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.tw(14, .semibold))
                .foregroundStyle(TWColor.ink3)
            TextField("搜食物或零食，例如 薯片 / 可乐 / 鸡胸", text: $query)
                .font(.tw(14.5))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.tw(14))
                        .foregroundStyle(TWColor.ink3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TWColor.glass(0.75))
        }
    }

    private var scanEntry: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showScan = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "barcode.viewfinder")
                    .font(.tw(18, .bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("扫包装条码")
                        .font(.tw(14.5, .bold))
                    Text("包装零食最准：直接读到厂商申报的营养表和配料")
                        .font(.tw(11))
                        .opacity(0.8)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.tw(11, .bold))
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [TWColor.purple, TWColor.blue],
                                         startPoint: .leading, endPoint: .trailing))
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ t: String) -> some View {
        HStack {
            Text(t)
                .font(.tw(11.5, .bold))
                .foregroundStyle(TWColor.ink3)
            Spacer()
        }
        .padding(.top, 2)
    }

    private func localRow(_ f: LocalFood) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            pick = FoodPick(
                name: f.name, group: f.group,
                kcal100: f.kcal, protein100: f.protein, carb100: f.carb, fat100: f.fat,
                fiber100: f.fiber, defaultGrams: f.portion,
                source: "本地库"
            )
        } label: {
            HStack(alignment: .center, spacing: 11) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(f.name)
                        .font(.tw(14.5, .semibold))
                        .foregroundStyle(TWColor.ink)
                    Text(f.macroLine)
                        .font(.tw(10.5))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Text("\(Int(f.portion))g")
                    .font(.tw(11, .bold))
                    .foregroundStyle(TWColor.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background { Capsule().fill(TWColor.purple.opacity(0.11)) }
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func remoteRow(_ f: RemoteFood) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            pick = FoodPick(
                name: f.name,
                brand: f.brand,
                kcal100: f.kcal100, protein100: f.protein100, carb100: f.carb100,
                fat100: f.fat100, fiber100: f.fiber100,
                defaultGrams: f.servingGrams > 0 ? f.servingGrams : 100,
                source: "Open Food Facts",
                ingredients: f.ingredients,
                imageURL: f.imageURL
            )
        } label: {
            HStack(alignment: .center, spacing: 11) {
                if !f.imageURL.isEmpty, let u = URL(string: f.imageURL) {
                    AsyncImage(url: u) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            Rectangle().fill(TWColor.purple.opacity(0.10))
                        }
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(f.brand.isEmpty ? f.name : "\(f.brand) · \(f.name)")
                        .font(.tw(14, .semibold))
                        .foregroundStyle(TWColor.ink)
                        .lineLimit(2)
                    Text(f.macroLine)
                        .font(.tw(10.5))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill")
                    .font(.tw(17))
                    .foregroundStyle(TWColor.purple)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("怎么搜才准")
                .font(.tw(13, .bold))
                .foregroundStyle(TWColor.ink2)
            Text("散装食物（米饭、鸡胸、苹果）用本地库，都是标准成分表数值。\n包装零食（薯片、可乐、饼干）直接扫条码，拿的是厂商官方营养表和配料，一条不差。\n搜不到就换关键词：搜“可乐”不如搜“百事可乐”。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TWColor.glass(0.5))
        }
    }

    // MARK: - 搜索

    private func scheduleSearch(_ q: String) {
        debounce?.cancel()
        local = FoodBase.search(q, limit: 30)

        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            remote = []
            loading = false
            errorText = nil
            return
        }

        let work = DispatchWorkItem {
            Task { await runRemote(trimmed) }
        }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    private func runRemote(_ q: String) async {
        await MainActor.run {
            loading = true
            errorText = nil
        }
        do {
            let list = try await FoodWeb.search(q)
            await MainActor.run {
                remote = list
                loading = false
                if list.isEmpty {
                    errorText = "联网没找到「\(q)」。换个叫法，或者直接扫条码。"
                }
            }
        } catch {
            await MainActor.run {
                loading = false
                errorText = (error as? LocalizedError)?.errorDescription ?? "联网失败，先用本地库"
            }
        }
    }
}

import SwiftUI
import AVFoundation
import UIKit

// MARK: - 克数确认

struct GramSheet: View {
    let pick: FoodPick
    let slot: String
    var onAdd: (MealEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double = 100
    @State private var showIngredients = false

    private var kcal: Double { pick.kcal100 * grams / 100 }
    private var p: Double { pick.protein100 * grams / 100 }
    private var c: Double { pick.carb100 * grams / 100 }
    private var f: Double { pick.fat100 * grams / 100 }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard
                    amountCard
                    macroCard
                    if !pick.ingredients.isEmpty {
                        ingredientsCard
                    }
                    addButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background { AuroraBG() }
            .navigationTitle("加到\(slot)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                grams = max(10, pick.defaultGrams)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pick.brand.isEmpty ? pick.name : "\(pick.brand) \(pick.name)")
                .font(.tw(20, .heavy, .rounded))
                .foregroundStyle(TWColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text(pick.source)
                    .font(.tw(10, .bold))
                    .foregroundStyle(TWColor.purple)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background { Capsule().fill(TWColor.purple.opacity(0.12)) }
                Text(String(format: "每100g %.0f kcal", pick.kcal100))
                    .font(.tw(11))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(grams))")
                    .font(.tw(38, .heavy, .rounded))
                    .foregroundStyle(TWColor.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("克")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink3)
                Spacer()
                HStack(spacing: 10) {
                    roundBtn("minus")
                    roundBtn("plus")
                }
            }

            Slider(value: $grams, in: 5...1000, step: 5)
                .tint(TWColor.purple)

            HStack(spacing: 8) {
                quick(30)
                quick(pick.defaultGrams > 0 ? pick.defaultGrams : 100)
                quick(150)
                quick(200)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .twGlass()
    }

    private func quick(_ g: Double) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.snappy) { grams = g }
        } label: {
            Text("\(Int(g))g")
                .font(.tw(11.5, .bold))
                .foregroundStyle(grams == g ? .white : TWColor.purple)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule().fill(grams == g ? TWColor.purple : TWColor.purple.opacity(0.12))
                }
        }
        .buttonStyle(.plain)
    }

    private func roundBtn(_ icon: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if icon == "minus" { grams = max(5, grams - 5) } else { grams = min(1000, grams + 5) }
        } label: {
            Image(systemName: icon)
                .font(.tw(13, .bold))
                .foregroundStyle(TWColor.purple)
                .frame(width: 32, height: 32)
                .background { Circle().fill(TWColor.purple.opacity(0.12)) }
        }
        .buttonStyle(.plain)
    }

    private var macroCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("这 \(Int(grams))g 折算")
                    .font(.tw(12, .bold))
                    .foregroundStyle(TWColor.ink3)
                Spacer()
                Text(String(format: "%.0f kcal", kcal))
                    .font(.tw(17, .heavy, .rounded))
                    .foregroundStyle(TWColor.ink)
                    .monospacedDigit()
            }
            .padding(.bottom, 10)

            HStack(spacing: 0) {
                macroCell("蛋白", String(format: "%.1f", p), TWColor.purple)
                macroCell("碳水", String(format: "%.1f", c), TWColor.blue)
                macroCell("脂肪", String(format: "%.1f", f), TWColor.amber)
                if pick.fiber100 > 0 {
                    macroCell("纤维", String(format: "%.1f", pick.fiber100 * grams / 100), TWColor.mint)
                }
            }
        }
        .padding(16)
        .twGlass()
    }

    private func macroCell(_ t: String, _ v: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(v)
                .font(.tw(18, .heavy, .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text("\(t) g")
                .font(.tw(10.5, .semibold))
                .foregroundStyle(TWColor.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { showIngredients.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.tw(12, .semibold))
                    Text("配料表（配方）")
                        .font(.tw(13, .bold))
                    Spacer()
                    Image(systemName: showIngredients ? "chevron.up" : "chevron.down")
                        .font(.tw(10, .bold))
                }
                .foregroundStyle(TWColor.ink2)
            }
            .buttonStyle(.plain)

            if showIngredients {
                Text(pick.ingredients)
                    .font(.tw(11.5))
                    .foregroundStyle(TWColor.ink3)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    private var addButton: some View {
        Button {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let veg: Double = pick.group == "蔬菜" ? grams : 0
            onAdd(MealEntry(
                name: pick.brand.isEmpty ? pick.name : "\(pick.brand) \(pick.name)",
                grams: grams,
                kcal: kcal,
                protein: p,
                carb: c,
                fat: f,
                veg: veg,
                slot: slot,
                time: Date()
            ))
            dismiss()
        } label: {
            Text(String(format: "加入 %@ · %.0f kcal", slot, kcal))
                .font(.tw(16, .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 条码扫描

final class BarcodeScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    @Published var scanned: String?
    @Published var denied = false
    private var configured = false

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { ok in
            DispatchQueue.main.async {
                if !ok { self.denied = true; return }
                self.configure()
                DispatchQueue.global(qos: .userInitiated).async {
                    if !self.session.isRunning { self.session.startRunning() }
                }
            }
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configure() {
        guard !configured else { return }
        configured = true

        guard let dev = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: dev) else {
            denied = true
            return
        }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }

        let out = AVCaptureMetadataOutput()
        if session.canAddOutput(out) {
            session.addOutput(out)
            out.setMetadataObjectsDelegate(self, queue: .main)
            out.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39]
        }
        session.commitConfiguration()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard scanned == nil else { return }
        if let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let v = obj.stringValue, v.count >= 8 {
            scanned = v
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = v.bounds
        v.layer.addSublayer(layer)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let l = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            l.frame = uiView.bounds
        }
    }
}

private struct NoteTarget: Identifiable {
    let id = UUID()
    var code: String
}

struct BarcodeScanSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    let slot: String

    @StateObject private var scanner = BarcodeScanner()
    @State private var manual = ""
    @State private var result: RemoteFood?
    @State private var errorText: String?
    @State private var searching = false
    @State private var pick: FoodPick?
    /// 查不到时准备建档的条码（String 不是 Identifiable，包一层给 sheet 用）
    @State private var noteTarget: NoteTarget?
    @State private var lastCode = ""
    /// 这条是从本机缓存直接出来的，没联网
    @State private var fromCache = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                if scanner.denied {
                    deniedView
                } else {
                    ZStack {
                        CameraPreview(session: scanner.session)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .frame(height: 300)

                        // 取景框
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                            .frame(width: 250, height: 120)
                    }
                    .overlay(alignment: .bottom) {
                        Text("把包装上的条形码放进框里")
                            .font(.tw(11.5, .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background { Capsule().fill(Color.black.opacity(0.45)) }
                            .padding(.bottom, 10)
                    }
                }

                manualRow

                if searching {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("查库里这个条码…")
                            .font(.tw(12.5))
                            .foregroundStyle(TWColor.ink3)
                    }
                }

                if let e = errorText {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(e)
                            .font(.tw(12))
                            .foregroundStyle(TWColor.amber)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            noteTarget = NoteTarget(code: lastCode.isEmpty ? manual : lastCode)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.tw(11, .bold))
                                Text("这个条码我来建档")
                                    .font(.tw(12.5, .bold))
                            }
                            .foregroundStyle(TWColor.purple)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background { Capsule().fill(TWColor.purple.opacity(0.12)) }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let r = result {
                    resultCard(r)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .background { AuroraBG() }
            .navigationTitle("扫条码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear { scanner.start() }
            .onDisappear { scanner.stop() }
            .onChange(of: scanner.scanned) { _, code in
                guard let code, !code.isEmpty else { return }
                lookup(code)
            }
            .sheet(item: $noteTarget) { t in
                BarcodeNoteSheet(code: t.code) { note in
                    store.saveBarcodeNote(note)
                    result = RemoteFood(code: note.code, name: note.name, brand: note.brand,
                                        kcal100: note.kcal100, protein100: note.protein100,
                                        carb100: note.carb100, fat100: note.fat100,
                                        fiber100: 0, sugar100: 0, salt100: 0,
                                        ingredients: "", imageURL: "",
                                        servingGrams: note.servingGrams, quantity: "")
                    errorText = nil
                }
                .environmentObject(store)
            }
            .sheet(item: $pick) { p in
                GramSheet(pick: p, slot: slot) { entry in
                    store.addMeal(entry)
                    dismiss()
                }
                .presentationDetents([.large])
                .presentationCornerRadius(28)
            }
        }
    }

    private var deniedView: some View {
        VStack(spacing: 9) {
            Image(systemName: "camera.fill")
                .font(.tw(26))
                .foregroundStyle(TWColor.ink3)
            Text("相机没被允许")
                .font(.tw(15, .bold))
                .foregroundStyle(TWColor.ink)
            Text("设置 → 隐私与安全 → 相机 → 天才威 打开，或者下面手动输入条码。")
                .font(.tw(12))
                .foregroundStyle(TWColor.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .twGlass()
    }

    private var manualRow: some View {
        HStack(spacing: 9) {
            TextField("手动输入条码，例如 6920000000000", text: $manual)
                .font(.tw(14))
                .keyboardType(.numberPad)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(TWColor.glass(0.7))
                }

            Button {
                lookup(manual)
            } label: {
                Text("查")
                    .font(.tw(14.5, .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 42)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(TWColor.purple)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private func resultCard(_ r: RemoteFood) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if !r.imageURL.isEmpty, let u = URL(string: r.imageURL) {
                    AsyncImage(url: u) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            Rectangle().fill(TWColor.purple.opacity(0.1))
                        }
                    }
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.brand.isEmpty ? r.name : "\(r.brand) · \(r.name)")
                        .font(.tw(15, .bold))
                        .foregroundStyle(TWColor.ink)
                        .lineLimit(2)
                    Text(r.quantity.isEmpty ? r.code : "\(r.quantity) · \(r.code)")
                        .font(.tw(10.5))
                        .foregroundStyle(TWColor.ink3)
                }
                Spacer(minLength: 0)
            }

            if fromCache {
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .font(.tw(9, .bold))
                    Text("本机记录 · 不联网秒出")
                        .font(.tw(10, .bold))
                }
                .foregroundStyle(TWColor.mint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background { Capsule().fill(TWColor.mint.opacity(0.12)) }
            }

            Text(r.macroLine)
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(2)

            if !r.ingredients.isEmpty {
                Text(r.ingredients)
                    .font(.tw(10.5))
                    .foregroundStyle(TWColor.ink3)
                    .lineLimit(4)
                    .lineSpacing(2)
            }

            Button {
                pick = FoodPick(
                    name: r.name, brand: r.brand,
                    kcal100: r.kcal100, protein100: r.protein100, carb100: r.carb100,
                    fat100: r.fat100, fiber100: r.fiber100,
                    defaultGrams: r.servingGrams > 0 ? r.servingGrams : 100,
                    source: "Open Food Facts（厂商申报）",
                    ingredients: r.ingredients,
                    imageURL: r.imageURL
                )
            } label: {
                Text("记这一份")
                    .font(.tw(14.5, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(LinearGradient(colors: [TWColor.purple, TWColor.blue],
                                                 startPoint: .leading, endPoint: .trailing))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .twGlass()
    }

    private func lookup(_ code: String) {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 8 else {
            errorText = "条码至少 8 位，检查一下"
            return
        }
        lastCode = clean
        errorText = nil
        result = nil

        // 1) 先查本机条码库：扫过的码不用再联网
        if let n = store.barcodeNote(clean) {
            searching = false
            fromCache = true
            result = RemoteFood(code: n.code, name: n.name, brand: n.brand,
                                kcal100: n.kcal100, protein100: n.protein100,
                                carb100: n.carb100, fat100: n.fat100,
                                fiber100: 0, sugar100: 0, salt100: 0,
                                ingredients: "", imageURL: "",
                                servingGrams: n.servingGrams, quantity: "")
            return
        }

        searching = true

        Task {
            do {
                let f = try await FoodWeb.barcode(clean)
                await MainActor.run {
                    result = f
                    searching = false
                    fromCache = false
                    // 联网查到的也留一份在本机，下次秒出、断网也能用
                    store.saveBarcodeNote(BarcodeNote(
                        code: clean, name: f.name, brand: f.brand,
                        kcal100: f.kcal100, protein100: f.protein100,
                        carb100: f.carb100, fat100: f.fat100,
                        servingGrams: f.servingGrams, fromWeb: true, at: Date()))
                }
            } catch {
                await MainActor.run {
                    searching = false
                    errorText = (error as? LocalizedError)?.errorDescription ?? "查不到这个条码"
                }
            }
        }
    }
}

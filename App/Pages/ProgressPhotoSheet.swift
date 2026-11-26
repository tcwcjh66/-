import SwiftUI
import PhotosUI
import UIKit

/// 进度照：按月攒几张，两张并排看变化。
struct ProgressPhotoSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var pick: PhotosPickerItem?
    @State private var busy = false
    @State private var left: ProgressPhoto?
    @State private var right: ProgressPhoto?
    @State private var msg: String?

    private var photos: [ProgressPhoto] { store.progressPhotos }

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if photos.isEmpty {
                        emptyCard
                    } else {
                        compareCard
                        gridCard
                    }

                    addCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            guard left == nil, right == nil, !photos.isEmpty else { return }
            right = photos.first
            left = photos.count > 1 ? photos.last : nil
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("进度照")
                    .font(.tw(26, .heavy, .rounded))
                    .foregroundStyle(TWColor.ink)
                Text("同样的光线、同样的角度，一个月拍一张就够")
                    .font(.tw(11.5))
                    .foregroundStyle(TWColor.ink3)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.tw(12, .bold))
                    .foregroundStyle(TWColor.ink2)
                    .frame(width: 32, height: 32)
                    .background { Circle().fill(TWColor.glass(0.6)) }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("还没有照片")
                .font(.tw(14, .bold))
                .foregroundStyle(TWColor.ink)
            Text("拍第一张开始，以后每张都能挑出来跟旧的并排比。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass(radius: 20)
    }

    private var compareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.split.2x1")
                    .font(.tw(12, .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("并排对比")
                    .font(.tw(14, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                if let l = left, let r = right {
                    Text(spanText(l, r))
                        .font(.tw(10.5, .semibold))
                        .foregroundStyle(TWColor.purple)
                }
            }

            HStack(spacing: 8) {
                slot(left, hint: "点左侧选旧图")
                slot(right, hint: "点右侧选新图")
            }

            if photos.count == 1 {
                Text("只有一张照片，再拍一张就能对比了。")
                    .font(.tw(10.5))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .padding(14)
        .twGlass(radius: 20)
    }

    @ViewBuilder
    private func slot(_ p: ProgressPhoto?, hint: String) -> some View {
        Button {
            swapSlots()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(TWColor.glass(0.14))
                if let p, let img = store.progressImage(p) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack {
                        Spacer()
                        HStack {
                            Text(p.date)
                                .font(.tw(9.5, .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background { Capsule().fill(.black.opacity(0.42)) }
                            Spacer()
                        }
                        .padding(6)
                    }
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                            .font(.tw(19, .semibold))
                            .foregroundStyle(TWColor.ink3)
                        Text(hint)
                            .font(.tw(9.5))
                            .foregroundStyle(TWColor.ink3)
                    }
                }
            }
            .frame(height: 200)
        }
        .buttonStyle(.plain)
    }

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                    .font(.tw(12, .semibold))
                    .foregroundStyle(TWColor.blue)
                Text("全部 \(photos.count) 张")
                    .font(.tw(14, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Text("长按删")
                    .font(.tw(10))
                    .foregroundStyle(TWColor.ink3)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                      spacing: 8) {
                ForEach(photos) { p in
                    ZStack(alignment: .bottomLeading) {
                        if let img = store.progressImage(p) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 132)
                                .clipped()
                        } else {
                            Rectangle().fill(TWColor.glass(0.14)).frame(height: 132)
                        }
                        Text(p.date)
                            .font(.tw(9.5, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background { Capsule().fill(.black.opacity(0.42)) }
                            .padding(6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteProgressPhoto(p)
                            if left?.id == p.id { left = nil }
                            if right?.id == p.id { right = nil }
                        } label: {
                            Label("删掉这张", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(14)
        .twGlass(radius: 20)
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhotosPicker(selection: $pick, matching: .images) {
                HStack(spacing: 7) {
                    Image(systemName: busy ? "hourglass" : "camera.fill")
                        .font(.tw(13, .bold))
                    Text(busy ? "正在存…" : "加一张进度照")
                        .font(.tw(14, .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background {
                    Capsule().fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                  startPoint: .leading, endPoint: .trailing))
                }
            }
            .disabled(busy)

            if let msg {
                Text(msg)
                    .font(.tw(10.5))
                    .foregroundStyle(TWColor.coral)
            }

            Text("会压到 1200 像素宽再存，一张约 200 KB；最多留 40 张，旧的自动清。")
                .font(.tw(10))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .twGlass(radius: 20)
    }

    private func swapSlots() {
        let t = left
        left = right
        right = t
    }

    private func spanText(_ a: ProgressPhoto, _ b: ProgressPhoto) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d1 = f.date(from: a.date), let d2 = f.date(from: b.date) else { return "" }
        let days = abs(Calendar.current.dateComponents([.day], from: d1, to: d2).day ?? 0)
        if days >= 30 { return "相隔 \(days / 30) 个月" }
        if days >= 7 { return "相隔 \(days / 7) 周" }
        return "相隔 \(days) 天"
    }

    @MainActor
    private func importPhoto(_ item: PhotosPickerItem) async {
        busy = true
        defer { busy = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let img = UIImage(data: data) else {
            msg = "这张读不出来，换一张试试"
            return
        }
        let ok = store.addProgressPhoto(img, note: "")
        msg = ok ? nil : "存失败，可能空间不够"
        pick = nil
    }
}

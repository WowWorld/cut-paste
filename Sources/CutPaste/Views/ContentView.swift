import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ClipboardStore

    var body: some View {
        ZStack {
            AmbientPasteInspiredBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                heroHeader
                ClipboardShelfView(style: .library)
                    .environmentObject(store)
            }
            .padding(28)
        }
        .frame(minWidth: 980, minHeight: 720)
    }

    private var heroHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 28, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .white.opacity(0.55))
                    Text("Cut Paste")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("按 Command + Shift + V 呼出底部 Shelf；复制文本、链接、图片和文件后会自动出现在这里。")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(store.items.count)")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("clipboard items")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct AmbientPasteInspiredBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.43, blue: 0.05),
                    Color(red: 1.00, green: 0.68, blue: 0.12),
                    Color(red: 0.93, green: 0.30, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 720, height: 720)
                .blur(radius: 12)
                .offset(x: -390, y: -260)

            Circle()
                .fill(Color(red: 0.30, green: 0.74, blue: 1.0).opacity(0.22))
                .frame(width: 560, height: 560)
                .blur(radius: 26)
                .offset(x: 430, y: 280)

            RoundedRectangle(cornerRadius: 180, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 34)
                .frame(width: 760, height: 420)
                .rotationEffect(.degrees(-18))
                .offset(x: -320, y: 300)
        }
    }
}

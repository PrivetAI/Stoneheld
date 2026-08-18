import SwiftUI

struct CairnBalanceLoadingScreen: View {
    @State private var settle: Double = 0

    var body: some View {
        ZStack {
            CBBackground()
            VStack(spacing: 22) {
                Canvas { ctx, size in
                    var c = ctx
                    let rect = CGRect(x: size.width * 0.16, y: 0,
                                      width: size.width * 0.68, height: size.height)
                    CBRender.drawCairn(&c,
                                       kindIDs: [9, 2, 20, 5, 33],
                                       xs: [0, 2, -5, 3, -1],
                                       ys: [16, 40, 74, 106, 144],
                                       rots: [0, 0.05, -0.04, 0.09, -0.02],
                                       in: rect, withBase: true)
                }
                .frame(width: 220, height: 200)
                .opacity(0.35 + settle * 0.65)

                VStack(spacing: 6) {
                    Text("Cairn Balance")
                        .font(CBTheme.displayBold(23))
                        .foregroundColor(CBTheme.ink)
                    Text("Finding the seat")
                        .font(CBTheme.label(12, .regular))
                        .foregroundColor(CBTheme.inkSoft)
                }

                Capsule()
                    .fill(CBTheme.paperDeep)
                    .frame(width: 120, height: 4)
                    .overlay(
                        GeometryReader { geo in
                            Capsule()
                                .fill(CBTheme.seaglass)
                                .frame(width: geo.size.width * CGFloat(settle))
                        }
                    )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                settle = 1
            }
        }
    }
}

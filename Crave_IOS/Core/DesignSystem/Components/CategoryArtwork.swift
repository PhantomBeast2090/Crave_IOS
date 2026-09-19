import SwiftUI

/// Crave category artwork: hand-built vector motifs (no clip-art, no assets).
/// One motif per food family, rendered as cream line-work on a brand-tinted
/// disc. Cheap enough for horizontal rails (Shape paths, no Canvas, no
/// per-frame work). Backend emojis are empty upstream, so this is the
/// category's visual identity — not a decoration fallback.
enum CategoryMotif: Sendable {
    case biryani
    case burger
    case pizza
    case drinks
    case desserts
    case southIndian
    case chinese
    case snacks
    case generic

    /// Keyword match on the backend category name. Unknown names get the
    /// generic bowl — never a random SF Symbol.
    static func of(_ name: String) -> CategoryMotif {
        let n = name.lowercased()
        if n.contains("biryani") || n.contains("pulao") || n.contains("rice") || n.contains("meals") { return .biryani }
        if n.contains("burger") || n.contains("sandwich") || n.contains("roll") || n.contains("wrap") || n.contains("shawarma") || n.contains("kubos") { return .burger }
        if n.contains("pizza") { return .pizza }
        if n.contains("juice") || n.contains("shake") || n.contains("beverage") || n.contains("drink") || n.contains("coffee") || n.contains("tea") || n.contains("lime") || n.contains("soda") || n.contains("mojito") || n.contains("milk") { return .drinks }
        if n.contains("dessert") || n.contains("ice cream") || n.contains("cake") || n.contains("sweet") || n.contains("brownie") || n.contains("kulfi") || n.contains("falooda") { return .desserts }
        if n.contains("dosa") || n.contains("idli") || n.contains("vada") || n.contains("south") { return .southIndian }
        if n.contains("chinese") || n.contains("noodle") || n.contains("momos") || n.contains("manchuria") || n.contains("schezwan") || n.contains("hakka") { return .chinese }
        if n.contains("snack") || n.contains("chat") || n.contains("fries") || n.contains("samosa") || n.contains("pakoda") || n.contains("65") || n.contains("tikka") || n.contains("kebab") || n.contains("kabab") { return .snacks }
        return .generic
    }
}

/// A steam wisp used by bowl motifs.
private struct SteamLine: Shape {
    var xOffset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let baseX = rect.minX + w * 0.5 + xOffset
        path.move(to: CGPoint(x: baseX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: baseX, y: rect.minY),
            control1: CGPoint(x: baseX - w * 0.25, y: rect.maxY - rect.height * 0.35),
            control2: CGPoint(x: baseX + w * 0.25, y: rect.maxY - rect.height * 0.65)
        )
        return path
    }
}

/// Category medallion: tinted disc + cream motif line-work.
struct CategoryArtwork: View {
    let motif: CategoryMotif
    var size: CGFloat = 56

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(GagColors.cravePrimaryContainer)
            motifBody
                .padding(size * 0.24)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var motifBody: some View {
        switch motif {
        case .biryani, .generic:
            VStack(spacing: 1) {
                HStack(spacing: 5) {
                    stroked(SteamLine(xOffset: -4))
                        .frame(width: 8, height: 12)
                    stroked(SteamLine(xOffset: 0))
                        .frame(width: 8, height: 14)
                    stroked(SteamLine(xOffset: 4))
                        .frame(width: 8, height: 12)
                }
                stroked(BowlShape())
            }
        case .burger:
            VStack(spacing: 2.5) {
                stroked(BurgerTop())
                stroked(RoundedRectangle(cornerRadius: 2))
                    .frame(height: 3)
                stroked(RoundedRectangle(cornerRadius: 2))
                    .frame(height: 3)
            }
        case .pizza:
            stroked(PizzaSlice())
        case .drinks:
            HStack(alignment: .bottom, spacing: 3) {
                stroked(CupShape())
                stroked(StrawShape())
                    .frame(width: 3, height: 22)
            }
        case .desserts:
            VStack(spacing: 1) {
                stroked(Circle())
                    .frame(width: 10, height: 10)
                stroked(DessertCup())
            }
        case .southIndian:
            stroked(DosaSpiral())
        case .chinese:
            VStack(spacing: 1) {
                stroked(Chopsticks())
                    .frame(height: 12)
                stroked(BowlShape())
            }
        case .snacks:
            stroked(SnackBox())
        }
    }

    private func stroked<S: Shape>(_ shape: S) -> some View {
        shape
            .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            .foregroundStyle(GagColors.cravePrimary)
            .padding(size * 0.02)
    }
}

// MARK: - Motif shapes (unit-space geometry, stroked by the parent)

private struct BowlShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + 2),
            radius: min(rect.width, rect.height * 1.6) / 2,
            startAngle: .degrees(15),
            endAngle: .degrees(165),
            clockwise: false
        )
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY + 2))
        return path
    }
}

private struct BurgerTop: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct PizzaSlice: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 2))
        path.closeSubpath()
        return path
    }
}

private struct CupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 6, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 6, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct StrawShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 1, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX + 3, y: rect.minY))
        return path
    }
}

private struct DessertCup: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct DosaSpiral: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxR = min(rect.width, rect.height) / 2 - 1
        var angle: Double = 0
        var first = true
        while angle < Double.pi * 5 {
            let r = maxR * angle / (Double.pi * 5)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * r,
                y: center.y + CGFloat(sin(angle)) * r
            )
            if first {
                path.move(to: point)
                first = false
            } else {
                path.addLine(to: point)
            }
            angle += 0.15
        }
        return path
    }
}

private struct Chopsticks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - 8, y: rect.minY))
        path.move(to: CGPoint(x: rect.minX + 8, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
        return path
    }
}

private struct SnackBox: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let boxTop = rect.minY + rect.height * 0.35
        path.move(to: CGPoint(x: rect.minX + 3, y: boxTop))
        path.addLine(to: CGPoint(x: rect.maxX - 3, y: boxTop))
        path.addLine(to: CGPoint(x: rect.maxX - 6, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: rect.minX + 6, y: rect.maxY - 1))
        path.closeSubpath()
        // snack sticks
        path.move(to: CGPoint(x: rect.midX - 5, y: boxTop))
        path.addLine(to: CGPoint(x: rect.midX - 7, y: rect.minY + 1))
        path.move(to: CGPoint(x: rect.midX, y: boxTop))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.move(to: CGPoint(x: rect.midX + 5, y: boxTop))
        path.addLine(to: CGPoint(x: rect.midX + 7, y: rect.minY + 1))
        return path
    }
}

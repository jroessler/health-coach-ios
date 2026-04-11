import SwiftUI
import UIKit

// MARK: - Core Animation spinner (render-server side — immune to main-thread
// blocks, SwiftUI transaction context, and gesture-gate conflicts)

private final class SpinningSymbolUIView: UIView {
    private let imageView = UIImageView()

    init(systemName: String, pointSize: CGFloat, tintColor: UIColor) {
        super.init(frame: .zero)
        let cfg = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        imageView.image = UIImage(systemName: systemName, withConfiguration: cfg)
        imageView.tintColor = tintColor
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        imageView.layer.removeAllAnimations()
        guard window != nil else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = Double.pi * 2
        spin.duration = 1.4
        spin.repeatCount = .infinity
        spin.isRemovedOnCompletion = false
        imageView.layer.add(spin, forKey: "spin")
    }
}

private struct SpinningSymbol: UIViewRepresentable {
    let systemName: String
    let pointSize: CGFloat
    let color: Color

    func makeUIView(context: Context) -> SpinningSymbolUIView {
        SpinningSymbolUIView(
            systemName: systemName,
            pointSize: pointSize,
            tintColor: UIColor(color)
        )
    }

    func updateUIView(_ uiView: SpinningSymbolUIView, context: Context) {}
}

// MARK: - LoadingView

struct LoadingView: View {
    var message: String = "Loading..."

    @State private var isPulsing = false
    private let accentCyan = Color(hex: 0x22D3EE)

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(accentCyan.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isPulsing ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                SpinningSymbol(systemName: "dumbbell.fill", pointSize: 44, color: accentCyan)
                    .frame(width: 52, height: 52)
            }
            .onAppear {
                // Scale animation is fine with a single deferred flip.
                DispatchQueue.main.async { isPulsing = true }
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

#Preview {
    ZStack {
        Color(hex: 0x02161C).ignoresSafeArea()
        LoadingView(message: "Computing nutrition data...")
    }
}

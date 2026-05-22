import SwiftUI

// MARK: - App Screens

enum AppScreen: String, CaseIterable {
    case cosmos  = "COSMOS"
    case aurora  = "AURORA"
    case crystal = "CRYSTAL"
    case animal  = "ANIMAL"
    case flower    = "FLOWER"
    case hourglass = "HOURGLASS"
    case clock     = "CLOCK"

    var icon: String {
        switch self {
        case .cosmos:     "sparkles"
        case .aurora:     "wind"
        case .crystal:    "diamond"
        case .animal:     "pawprint.fill"
        case .flower:     "camera.macro"
        case .hourglass:  "hourglass"
        case .clock:      "clock"
        }
    }

    var accent: Color {
        switch self {
        case .cosmos:     Color(red: 0.70, green: 0.80, blue: 0.92)
        case .aurora:     Color(red: 0.20, green: 0.85, blue: 0.55)
        case .crystal:    Color(red: 0.55, green: 0.88, blue: 1.00)
        case .animal:     Color(red: 1.00, green: 0.72, blue: 0.28)
        case .flower:     Color(red: 1.00, green: 0.60, blue: 0.75)
        case .hourglass:  Color(red: 0.95, green: 0.78, blue: 0.45)
        case .clock:      Color(red: 0.55, green: 0.45, blue: 0.90)
        }
    }
}

// MARK: - Root Router

struct ContentView: View {
    @State private var currentScreen: AppScreen = .cosmos
    @State private var showPicker = true

    var body: some View {
        ZStack {
            switch currentScreen {
            case .cosmos:
                CosmosView(onPickerTap: { showPicker = true })
            case .aurora:
                AuroraView(onPickerTap: { showPicker = true })
            case .crystal:
                CrystalView(onPickerTap: { showPicker = true })
            case .animal:
                AnimalView(onPickerTap: { showPicker = true })
            case .flower:
                FlowerView(onPickerTap: { showPicker = true })
            case .hourglass:
                HourglassView(onPickerTap: { showPicker = true })
            case .clock:
                ClockView(onPickerTap: { showPicker = true })
            }

            if showPicker {
                ScreenPickerOverlay(current: $currentScreen, isShowing: $showPicker)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showPicker)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Screen Picker Overlay

struct ScreenPickerOverlay: View {
    @Binding var current: AppScreen
    @Binding var isShowing: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .onTapGesture { isShowing = false }

            VStack(spacing: 36) {
                Text("SELECT CANVAS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.40))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 14) {
                    ForEach(AppScreen.allCases, id: \.self) { screen in
                        ScreenCard(screen: screen, isSelected: current == screen)
                            .onTapGesture {
                                current = screen
                                isShowing = false
                            }
                    }
                }
                .padding(.horizontal, 28)
            }
        }
    }
}

// MARK: - Screen Card

struct ScreenCard: View {
    let screen: AppScreen
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: screen.icon)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(isSelected ? .black : screen.accent)

            Text(screen.rawValue)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(isSelected ? .black : .white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            isSelected
                ? LinearGradient(
                    colors: [screen.accent, screen.accent.opacity(0.75)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                  )
                : LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                  )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    isSelected ? .clear : Color.white.opacity(0.13),
                    lineWidth: 1
                )
        )
        .shadow(color: isSelected ? screen.accent.opacity(0.45) : .clear, radius: 18)
    }
}

#Preview { ContentView() }

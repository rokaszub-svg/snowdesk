import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var prefs = Prefs.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Snowfall") {
                LabeledSlider(title: "Amount", value: $prefs.intensity, range: 0.1...1.5)
                LabeledSlider(title: "Speed", value: $prefs.speed, range: 0.4...2.0)
                LabeledSlider(title: "Wind", value: $prefs.wind, range: -1.0...1.0)
                LabeledSlider(title: "Flake size", value: $prefs.flakeSize, range: 0.6...1.8)
            }
            Section("Accumulation") {
                Toggle("Snow piles up on windows and the Dock", isOn: $prefs.accumulate)
                LabeledSlider(title: "Max depth", value: $prefs.maxPile, range: 4...30)
                Toggle("Snowballs", isOn: $prefs.snowballs)
            }
            Section("General") {
                Toggle("Snow on all displays", isOn: $prefs.allScreens)
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in setLaunchAtLogin(newValue) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.secondary)
                }
                Button("Reset to defaults") { prefs.resetToDefaults() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Move the app to Applications first, then try again."
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(title).frame(width: 90, alignment: .leading)
            Slider(value: $value, in: range)
        }
    }
}

import SwiftUI
import ReplayKit

struct ContentView: View {
    // Identificador del App Group compartido con la Broadcast Extension
    private let appGroupSuite = "group.com.matias.screenmirror"
    
    @State private var serverUrl: String = "http://192.168.1.38:3000"
    @State private var roomCode: String = ""
    @State private var statusMessage: String = "Ingresa el código que ves en la pantalla de tu TV o PC"
    @State private var isConfigured: Bool = false
    @State private var selectedQuality: Int = 1 // 0: Bajo, 1: Medio, 2: Alto

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Cabecera
                    VStack(spacing: 8) {
                        Image(systemName: "tv.and.mediabox")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Screen Mirroring")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Transmite a tu PC o Smart TV sin suscripciones")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // 2. Tarjeta de Configuración
                    VStack(alignment: .leading, spacing: 16) {
                        Text("1. Datos de Conexión")
                            .font(.headline)
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Dirección del Servidor:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("http://192.168.1.X:3000", text: $serverUrl)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Código de Sala (6 dígitos de la tele/PC):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Ej: 482913", text: $roomCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Perfil de Calidad:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Calidad", selection: $selectedQuality) {
                                Text("Baja (Fluido)").tag(0)
                                Text("Media (1080p)").tag(1)
                                Text("Alta (60 FPS)").tag(2)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }

                        Button(action: saveConfiguration) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Guardar y Vincular")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(roomCode.count >= 4 ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(roomCode.count < 4)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // 3. Estado de Configuración
                    HStack {
                        Image(systemName: isConfigured ? "checkmark.circle" : "info.circle")
                            .foregroundColor(isConfigured ? .green : .orange)
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // 4. Botón Nativo ReplayKit de Transmisión
                    VStack(spacing: 12) {
                        Text("2. Iniciar Transmisión de Pantalla")
                            .font(.headline)
                        
                        Text("Toca el botón rojo para abrir la ventana de transmisión del sistema:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Selector nativo de ReplayKit
                        BroadcastPickerView(extensionBundleId: "com.matias.screenmirror.extension")
                            .frame(width: 60, height: 60)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.red, lineWidth: 2)
                            )
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // 5. Guía Rápida
                    VStack(alignment: .leading, spacing: 8) {
                        Label("¿Cómo funciona?", systemImage: "questionmark.circle")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("• Asegúrate de que el iPhone y la tele/PC estén conectados al mismo Wi-Fi.\n• Si estás fuera de la app, también puedes iniciar la transmisión desde el Centro de Control de iOS manteniendo presionado el botón de Grabación.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
            .onAppear(perform: loadConfiguration)
        }
    }

    private func saveConfiguration() {
        let cleanUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCode = roomCode.trimmingCharacters(in: .whitespacesAndNewlines)

        if let defaults = UserDefaults(suiteName: appGroupSuite) {
            defaults.set(cleanUrl, forKey: "serverUrl")
            defaults.set(cleanCode, forKey: "codigoSalaCompartido")
            defaults.set(selectedQuality, forKey: "qualityProfile")
            defaults.synchronize()
        }
        UserDefaults.standard.set(cleanUrl, forKey: "serverUrl")
        UserDefaults.standard.set(cleanCode, forKey: "codigoSalaCompartido")

        isConfigured = true
        statusMessage = "Comprobando conexión con tu PC..."

        // Test de red y vinculación directa con la PC
        guard let url = URL(string: "\(cleanUrl)/api/pair") else {
            statusMessage = "⚠️ URL inválida: \(cleanUrl)"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let jsonBody = ["roomCode": cleanCode]
        request.httpBody = try? JSONSerialization.data(withJSONObject: jsonBody)
        request.timeoutInterval = 4.0

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self.statusMessage = "✅ ¡Conexión con tu PC exitosa! Pulsa Iniciar Transmisión abajo."
                } else {
                    self.statusMessage = "⚠️ Guardado, pero tu iPhone no llega a la PC. ¿Están en el mismo Wi-Fi?"
                }
            }
        }.resume()
    }

    private func loadConfiguration() {
        let defaults = UserDefaults(suiteName: appGroupSuite) ?? UserDefaults.standard
        if let savedServer = defaults.string(forKey: "serverUrl"), !savedServer.isEmpty {
            serverUrl = savedServer
        }
        if let savedCode = defaults.string(forKey: "codigoSalaCompartido"), !savedCode.isEmpty {
            roomCode = savedCode
            isConfigured = true
            statusMessage = "✅ Sala \(savedCode) lista."
        }
        selectedQuality = defaults.integer(forKey: "qualityProfile")
    }
}

// Representación de UIView para el botón del sistema ReplayKit
struct BroadcastPickerView: UIViewRepresentable {
    let extensionBundleId: String

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        picker.preferredExtension = extensionBundleId
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

import SwiftUI
import ReplayKit

struct ContentView: View {
    // URL del servidor hardcodeada — la misma que la extensión usa como fallback
    private let hardcodedServerUrl = "http://192.168.1.38:3000"

    @State private var serverUrl: String = "http://192.168.1.38:3000"
    @State private var roomCode: String = ""
    @State private var statusMessage: String = "Ingresa el código de 6 dígitos que ves en la PC"
    @State private var isConfigured: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: - Cabecera
                    VStack(spacing: 8) {
                        Image(systemName: "tv.and.mediabox")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        Text("Screen Mirror")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Transmite tu pantalla a la PC o Smart TV")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // MARK: - Configuración
                    VStack(alignment: .leading, spacing: 16) {
                        Text("1. Configuración")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Dirección IP del servidor (PC):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("http://192.168.1.X:3000", text: $serverUrl)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Código de 6 dígitos (de la pantalla de la PC):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Ej: 482913", text: $roomCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                        }

                        Button(action: guardarYVincular) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Guardar y Vincular con la PC")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(roomCode.count >= 6 ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(roomCode.count < 6)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // MARK: - Estado
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundColor(isConfigured ? .green : .orange)
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // MARK: - Botón de transmisión
                    VStack(spacing: 12) {
                        Text("2. Iniciar Transmisión")
                            .font(.headline)

                        Text("Toca el botón rojo → selecciona ScreenMirror → Start Broadcast")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        BroadcastPickerView(extensionBundleId: "com.matias.screenmirror.extension")
                            .frame(width: 70, height: 70)

                        Text("El botón rojo activa la transmisión nativa de iOS")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // MARK: - Instrucciones
                    VStack(alignment: .leading, spacing: 10) {
                        Label("¿Cómo usarlo?", systemImage: "questionmark.circle")
                            .font(.subheadline).fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("① Abre el navegador en tu PC: http://192.168.1.38:3000")
                            Text("② Escribe el código de 6 dígitos que aparece en la pantalla")
                            Text("③ Toca \"Guardar y Vincular\"")
                            Text("④ Toca el botón rojo → ScreenMirror → Start Broadcast")
                            Text("⑤ ¡Tu pantalla aparece en la PC en segundos!")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
            .onAppear(perform: cargarConfiguracion)
        }
    }

    // MARK: - Acciones

    private func guardarYVincular() {
        let cleanUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCode = roomCode.trimmingCharacters(in: .whitespacesAndNewlines)

        // Guardar en UserDefaults estándar — la extensión también los lee
        UserDefaults.standard.set(cleanUrl, forKey: "serverUrl")
        UserDefaults.standard.set(cleanCode, forKey: "codigoSalaCompartido")
        UserDefaults.standard.synchronize()

        isConfigured = true
        statusMessage = "Comprobando conexión..."

        // Notificar al servidor la vinculación
        guard let url = URL(string: "\(cleanUrl)/api/pair") else {
            statusMessage = "⚠️ URL inválida"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["roomCode": cleanCode])
        request.timeoutInterval = 4.0

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    self.statusMessage = "✅ ¡Vinculado! Ahora toca el botón rojo para transmitir."
                } else {
                    self.statusMessage = "⚠️ Guardado localmente. Verifica que el servidor esté activo y que el iPhone y la PC estén en el mismo Wi-Fi."
                }
            }
        }.resume()
    }

    private func cargarConfiguracion() {
        let defaults = UserDefaults.standard
        if let url = defaults.string(forKey: "serverUrl"), !url.isEmpty {
            serverUrl = url
        }
        if let code = defaults.string(forKey: "codigoSalaCompartido"), !code.isEmpty {
            roomCode = code
            isConfigured = true
            statusMessage = "✅ Sala \(code) configurada. Listo para transmitir."
        }
    }
}

// MARK: - BroadcastPickerView nativo de ReplayKit

struct BroadcastPickerView: UIViewRepresentable {
    let extensionBundleId: String

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
        picker.preferredExtension = extensionBundleId
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

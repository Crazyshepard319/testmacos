// ASR Benchmark (iOS) -- Zadanie 4, runda 2.
//
// Odpowiednik android-benchmark/MainActivity.kt, ale przez WhisperKit
// (CoreML) zamiast sherpa-onnx -- nie ma sprawdzonej, publicznej konwersji
// Parakeet TDT v3 do CoreML, WhisperKit to gotowy, utrzymywany port.
//
// UWAGA: ten kod NIE zostal skompilowany ani przetestowany przez Claude'a --
// pisane na Linuksie bez dostepu do Xcode/macOS. Traktuj jako pierwszy
// szkic do przetestowania na miejscu (najpierw Symulator, potem realne
// urzadzenie), nie jako gotowy, zweryfikowany kod (w przeciwienstwie do
// wersji Androidowej, ktora ma potwierdzone BUILD SUCCESSFUL).

import AVFoundation
import SwiftUI
import WhisperKit

struct ContentView: View {
    @State private var log: String = ""
    @State private var status: String = "Gotowy. Naciśnij przycisk, aby zacząć."
    @State private var isRunning = false

    private let nRounds = 10 // Zadanie 4: RTF na 1., 5. i 10. kolejnym dyktowaniu bez przerwy

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { runBenchmark() }) {
                Text("Uruchom benchmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)

            Text(status)
                .font(.headline)

            ScrollView {
                Text(log)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding()
    }

    private func appendLog(_ line: String) {
        print("[asr-benchmark] \(line)")
        DispatchQueue.main.async { log += line + "\n" }
    }

    private func setStatus(_ s: String) {
        print("[asr-benchmark] STATUS: \(s)")
        DispatchQueue.main.async { status = s }
    }

    // Standardowy sposob odczytu residentnej pamieci procesu na iOS
    // (mach_task_basic_info) -- odpowiednik Debug.getMemoryInfo() z Androida.
    private func memoryUsageMB() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Double(taskInfo.resident_size) / (1024 * 1024)
    }

    private func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }

    private func audioDurationSeconds(path: String) -> Double {
        guard let audioFile = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) else {
            return -1
        }
        return Double(audioFile.length) / audioFile.fileFormat.sampleRate
    }

    private func runBenchmark() {
        isRunning = true
        log = ""
        Task {
            do {
                try await runBenchmarkAsync()
            } catch {
                appendLog("BŁĄD: \(error)")
                setStatus("Błąd — patrz log poniżej.")
            }
            isRunning = false
        }
    }

    private func runBenchmarkAsync() async throws {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"

        appendLog("=== ASR Benchmark iOS (runda 2, Zadanie 4) ===")
        appendLog("Czas: \(df.string(from: Date()))")
        appendLog("Urządzenie: \(deviceModelIdentifier()), iOS \(UIDevice.current.systemVersion)")
        appendLog("Model: WhisperKit (CoreML, model domyślny dla urządzenia)")
        appendLog("")

        // --- 1. Ładowanie modelu do pamięci ---
        // WhisperKit sam pobiera/cache'uje model przy pierwszym uruchomieniu
        // (z Hugging Face) -- na urządzeniu bez wcześniejszego cache to też
        // wlicza się w ten czas, podobnie jak w Androidzie na pierwszej
        // wersji z pobieraniem. Jeśli to okaże się problemem na device farmie
        // (wolna sieć / timeout), trzeba będzie zbadać opcję dołączenia
        // modelu do bundle -- patrz README.md w tym folderze.
        setStatus("Ładuję model (WhisperKit)...")
        let pssBeforeLoad = memoryUsageMB()
        let loadStart = Date()
        let pipe = try await WhisperKit()
        let loadTimeS = Date().timeIntervalSince(loadStart)
        let pssAfterLoad = memoryUsageMB()
        appendLog("Czas ładowania modelu do pamięci: \(String(format: "%.2f", loadTimeS)) s")
        appendLog("Pamięć przed/po załadowaniu: \(String(format: "%.0f", pssBeforeLoad)) MB -> " +
            "\(String(format: "%.0f", pssAfterLoad)) MB")
        appendLog("")

        // --- 2. Próbka kalibracyjna (dołączona do bundle aplikacji) ---
        guard let audioPath = Bundle.main.path(forResource: "calibration_sample", ofType: "wav") else {
            appendLog("BŁĄD: brak calibration_sample.wav w bundle aplikacji -- dodaj plik do projektu " +
                "(Target Membership zaznaczone) w Xcode.")
            setStatus("Błąd konfiguracji.")
            return
        }
        let durationS = audioDurationSeconds(path: audioPath)
        appendLog("Próbka kalibracyjna: \(String(format: "%.1f", durationS)) s")
        appendLog("")

        // --- 3. Pętla throttlingu: nRounds kolejnych dyktowań bez przerwy ---
        setStatus("Test throttlingu: 0/\(nRounds)...")
        var rtfs: [Double] = []
        var pssPerRound: [Double] = []
        var firstText = ""

        for round in 1...nRounds {
            setStatus("Test throttlingu: \(round)/\(nRounds)...")
            let t0 = Date()
            let results = try await pipe.transcribe(audioPath: audioPath)
            let elapsedS = Date().timeIntervalSince(t0)
            let text = results?.map(\.text).joined(separator: " ") ?? ""
            if round == 1 { firstText = text }

            let rtf = elapsedS / durationS
            rtfs.append(rtf)
            let pss = memoryUsageMB()
            pssPerRound.append(pss)

            appendLog(String(format: "  runda %2d: RTF=%.4f  (infer=%.3fs)  PSS=%.0fMB",
                round, rtf, elapsedS, pss))
        }

        // --- 4. Podsumowanie (ten sam format co wersja Android -- porównywalne) ---
        let sorted = rtfs.sorted()
        let median = sorted[sorted.count / 2]
        let p90 = sorted[min(Int(Double(sorted.count) * 0.9), sorted.count - 1)]
        let peakPss = pssPerRound.max() ?? 0

        appendLog("")
        appendLog("=== PODSUMOWANIE ===")
        appendLog("Rozpoznany tekst (runda 1): \(firstText)")
        appendLog(String(format: "RTF: median=%.4f  p90=%.4f  min=%.4f  max=%.4f",
            median, p90, sorted.first ?? 0, sorted.last ?? 0))
        appendLog(String(format: "Throttling: RTF runda 1=%.4f -> runda 5=%.4f -> runda 10=%.4f  (wzrost: %.1f%%)",
            rtfs[0], rtfs[4], rtfs[9], 100.0 * (rtfs[9] - rtfs[0]) / rtfs[0]))
        appendLog(String(format: "Peak PSS podczas dekodowania: %.0f MB", peakPss))
        appendLog(String(format: "Czas ładowania do pamięci: %.2f s", loadTimeS))

        // --- 5. Zapis do pliku (Files app -> On My iPhone, jeśli LSSupportsOpeningDocumentsInPlace=YES) ---
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outURL = docsURL.appendingPathComponent("benchmark_results.txt")
        try? log.write(to: outURL, atomically: true, encoding: .utf8)
        appendLog("")
        appendLog("Zapisano wynik do: \(outURL.path)")

        setStatus("Gotowe.")
    }
}

#Preview {
    ContentView()
}

# ASR Benchmark iOS (Zadanie 4)

Aplikacja do pomiaru RTF/RAM/throttlingu transkrypcji mowy na iPhone,
przez [WhisperKit](https://github.com/argmaxinc/WhisperKit) (CoreML).
Odpowiednik `android-benchmark/` na iOS.

**Status: kod przetestowany i działający** (zweryfikowany na Symulatorze
iOS — poprawnie rozpoznaje polską próbkę kalibracyjną). Nie testowany
jeszcze na prawdziwym iPhonie — do tego służy ta instrukcja.

## Co potrzebujesz

- Mac z zainstalowanym Xcode
- Kabel do podłączenia iPhone'a do tego Maca (Lightning albo USB-C, zależnie od modelu)
- iPhone z odblokowanym ekranem, żeby zatwierdzić "Trust This Computer"

To wszystko — **nie potrzeba żadnego konta Apple Developer płatnego, żadnego
eksportu `.ipa`, żadnej usługi typu Firebase/BrowserStack/AWS.** Podłączenie
telefonu bezpośrednio do Xcode i naciśnięcie Run wystarczy — Xcode sam
zajmie się podpisywaniem dla tego konkretnego telefonu automatycznie.

## Krok po kroku

### 1. Pobierz projekt

```
git clone https://github.com/Crazyshepard319/testmacos.git
cd testmacos
```

### 2. Stwórz projekt Xcode

1. Xcode → **File → New → Project**
2. **iOS → App**
3. Product Name: `ASRBenchmarkIOS`, Interface: **SwiftUI**, Language: **Swift**
4. Zapisz gdziekolwiek

### 3. Dodaj zależność WhisperKit

1. **File → Add Package Dependencies...**
2. Wklej: `https://github.com/argmaxinc/argmax-oss-swift`
3. Naciśnij Enter/Return w polu wyszukiwania (nawet jeśli pokaże "No Results" — to normalne, i tak rozwiąże adres)
4. **Add Package** → zaznacz produkt **WhisperKit** → **Add Package**

### 4. Podmień pliki

- Usuń wygenerowany `ContentView.swift` z projektu (prawy klik → Delete → Move to Trash)
- Przeciągnij `ContentView.swift` ze sklonowanego repo do nawigatora Xcode
- Przeciągnij też `calibration_sample.wav` ze sklonowanego repo do nawigatora Xcode
- Przy obu: zaznacz **"Copy items if needed"** i upewnij się, że checkbox przy targecie `ASRBenchmarkIOS` jest zaznaczony

### 5. Podłącz iPhone i uruchom

1. Podłącz iPhone kablem do Maca
2. Na telefonie zatwierdź **"Trust This Computer"** jeśli się pojawi
3. W Xcode, u góry obok przycisku ▶, wybierz z listy urządzeń **ten konkretny iPhone** (powinien pojawić się z nazwą, np. "iPhone (2)" albo jak go nazwaliście)
4. Kliknij ▶ (Run)

**Za pierwszym razem Xcode może poprosić o zalogowanie Apple ID** (Xcode →
Settings → Accounts, jeśli nie jest jeszcze zalogowany) — wystarczy zwykłe,
darmowe Apple ID, podłączony fizycznie telefon załatwia resztę.

**Może się też pojawić komunikat na samym iPhonie**: Ustawienia → Ogólne →
VPN i zarządzanie urządzeniem → zaufaj deweloperowi (jednorazowo, przy
pierwszej instalacji apki spoza App Store).

### 6. Test

Na ekranie telefonu (albo w symulatorze na Macu podczas testu) pojawi się
przycisk **"Uruchom benchmark"**. Kliknij go (na telefonie — dotknij palcem
albo dłonią jeśli robicie to fizycznie).

Apka zrobi 10 kolejnych transkrypcji tej samej 10-sekundowej próbki audio
(zawiera "VAS 6 na 10") bez przerwy, i pokaże na ekranie:
- RTF (median/p90) każdej rundy — realna szybkość na tym konkretnym iPhonie
- Throttling — czy runda 10 jest wolniejsza niż runda 1 (przegrzewanie)
- Zużycie pamięci (PSS) w każdej rundzie
- Rozpoznany tekst — powinno wyjść coś zbliżonego do oryginalnej treści po polsku

### 7. Zapisz wynik

Zrób zdjęcie/zrzut ekranu telefonu z pełnym podsumowaniem (przewiń log w
dół do sekcji "=== PODSUMOWANIE ===") — albo po prostu przepisz/wyślij mi
te kilka linijek tekstu, tak jak robiliśmy dla wyników z Androida.

**Powtórz na obu telefonach (iPhone 13 i iPhone 17)** — to jest ten sam
sens co dwa punkty danych z Androida (starszy vs najnowszy) i dokładnie
uzupełnia tabelę "model × urządzenie" z briefu o platformę iOS.

## Jeśli coś nie zadziała

- **Błąd kompilacji w Xcode** → wklej mi dokładną treść błędu (Issue
  Navigator — ikonka trójkąta z wykrzyknikiem w lewym pasku)
- **Ładowanie modelu trwa bardzo długo (minuty) przy pierwszym uruchomieniu**
  → to normalne, WhisperKit pobiera model (~630 MB) z sieci przy pierwszym
  starcie na danym urządzeniu. Drugie uruchomienie na tym samym telefonie
  powinno być dużo szybsze (model już zapisany lokalnie) — **do właściwego
  pomiaru RTF/throttlingu liczy się dopiero DRUGIE uruchomienie**, nie
  pierwsze (pierwsze zawiera czas pobierania, nie tylko ładowania)
- **"Rozpoznany tekst" pusty albo bez sensu** → to już naprawiony problem
  (wymuszony polski język w kodzie), ale jeśli się powtórzy — daj znać

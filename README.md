# ASR Benchmark iOS (Zadanie 4)

Odpowiednik `android-benchmark/` na iOS, przez [WhisperKit](https://github.com/argmaxinc/WhisperKit)
(CoreML) zamiast sherpa-onnx/Parakeet.

## Ważne zastrzeżenie -- to jest kod NIEZWERYFIKOWANY

W przeciwieństwie do `android-benchmark/` (który realnie skompilowałem i
przetestowałem -- `BUILD SUCCESSFUL`), ten kod **nie został skompilowany ani
uruchomiony przez Claude'a**. Piszę go z Linuksa, bez dostępu do Xcode/macOS
-- fizycznie nie da się zbudować `.ipa` bez Xcode, a Xcode działa tylko na
macOS. To pierwszy szkic do wspólnego przetestowania na Twoim Macu przez VNC,
nie gotowe, sprawdzone rozwiązanie. Jeśli Xcode zgłosi błąd kompilacji --
wklej mi go, poprawię kod na tej podstawie.

## Dlaczego WhisperKit, nie Parakeet

Nie ma sprawdzonej, publicznej konwersji Parakeet TDT v3 (transducer) do
CoreML -- brief wspomina, że robi to `vays.app`, ale narzędzie nie jest
publiczne. WhisperKit to gotowy, aktywnie utrzymywany port Whisper do
CoreML (Argmax) -- nic nie trzeba konwertować, tylko dodać jako zależność.

## Uwaga o podpisie (masz tylko darmowe Apple ID)

Firebase Test Lab dla iOS wymaga `.ipa` z **podpisem deweloperskim, nie
dystrybucyjnym**. Darmowe Apple ID (Personal Team) zwykle ogranicza podpis
deweloperski do niewielkiej liczby *zarejestrowanych* urządzeń -- a
urządzenia w farmie Firebase nie są zarejestrowane w Twoim koncie. **Nie mam
pewności, czy to faktycznie zablokuje instalację na farmie** (nie
testowałem) -- może się okazać, że działa, może nie. Jeśli `.ipa` nie
zainstaluje się na urządzeniu Firebase (błąd przy instalacji na farmie),
to jest dokładnie ten powód, i wtedy realna opcja to płatny Apple Developer
Program (99$/rok) -- albo spróbowanie BrowserStack App Live / AWS Device
Farm Remote Access, gdzie mechanizm instalacji może się różnić.

## Krok po kroku (na Macu, przez VNC)

### 1. Pobierz pliki z repo

```
git clone https://github.com/Crazyshepard319/testmacos.git
cd testmacos
```

(Pliki `ContentView.swift`, `README.md`, `calibration_sample.wav` są bezpośrednio w korzeniu tego repo.)

### 2. Stwórz nowy projekt Xcode (Xcode sam generuje poprawną strukturę --
### bezpieczniej niż ręcznie pisany plik projektu)

1. Xcode → **File → New → Project**
2. **iOS → App**
3. Product Name: `ASRBenchmarkIOS`, Interface: **SwiftUI**, Language: **Swift**
4. Zapisz projekt w dowolnym miejscu (np. obok tego folderu)

### 3. Dodaj WhisperKit jako zależność

1. **File → Add Package Dependencies...**
2. Wklej URL: `https://github.com/argmaxinc/argmax-oss-swift`
3. Wybierz regułę wersji (np. "Up to Next Major", from 0.9.0)
4. **Add Package** → z listy produktów zaznacz **WhisperKit** → **Add Package**

(Tak, adres repo to `argmax-oss-swift`, nie `WhisperKit` -- projekt się
przeniósł/skonsolidował pod nową nazwę; w kodzie nadal `import WhisperKit`.)

### 4. Podmień/dodaj pliki

1. Skopiuj zawartość `ContentView.swift` z tego folderu do
   `ContentView.swift` w swoim projekcie (nadpisz wygenerowany szablon).
2. Przeciągnij `calibration_sample.wav` (z tego folderu) do nawigatora
   projektu w Xcode. W oknie dialogowym: zaznacz **"Copy items if needed"**
   i upewnij się, że **Target Membership** dla `ASRBenchmarkIOS` jest
   zaznaczone (inaczej `Bundle.main.path(...)` go nie znajdzie).

### 5. Najpierw test na Symulatorze (szybka, bezpieczna weryfikacja)

1. U góry Xcode wybierz jako target dowolny symulator iPhone (np. "iPhone 16")
2. **Product → Run** (▶) albo Cmd+R
3. Jeśli się skompiluje i uruchomi -- kliknij **"Uruchom benchmark"** w
   symulatorze i sprawdź, czy log się wypełnia bez błędu.

**To nie mierzy realnej wydajności** (symulator ≠ prawdziwy chip) -- to
tylko sprawdza, że kod w ogóle działa, zanim przejdziesz do prawdziwego
urządzenia/eksportu.

Jeśli tu wystąpi błąd kompilacji -- wklej mi go w całości, poprawię kod.

### 6. Eksport `.ipa` z podpisem deweloperskim

1. U góry wybierz **"Any iOS Device (arm64)"** jako target (nie symulator)
2. **Product → Archive** (poczekaj, aż się zbuduje)
3. W oknie Organizer, który się otworzy: **Distribute App**
4. Wybierz **Development** (nie App Store Connect, nie Enterprise, nie Ad Hoc)
5. Xcode poprosi o wybór zespołu podpisującego -- wybierz swój Apple ID
   (Personal Team)
6. Dokończ kreator -- na końcu dostaniesz folder z plikiem `.ipa`

### 7. Wgraj `.ipa` do Firebase Test Lab

Dokładnie tak samo jak dla Androida: Firebase Console → Test Lab → Uruchom
test → Browse → wskaż `.ipa` → typ testu **Robo test** (iOS ma swój
odpowiednik automatycznego eksplorowania UI, tak jak Android) → wybierz
urządzenia → Start.

**Jeśli test padnie na etapie instalacji aplikacji** (nie na benchmarku) --
to prawdopodobnie właśnie ograniczenie podpisu z darmowego Apple ID, patrz
zastrzeżenie wyżej.

## Znane ryzyka, o których wiem z doświadczenia z Androidem

- **Pobieranie modelu przy starcie może się powtórzyć jako problem** --
  WhisperKit domyślnie pobiera model z Hugging Face przy pierwszym
  uruchomieniu, dokładnie jak pierwsza (wadliwa) wersja Androida. Jeśli
  test na Firebase pada w trakcie ładowania modelu / na timeoucie --to
  ten sam mechanizm, który już raz naprawiliśmy przez dołączenie modelu do
  APK. Dla iOS odpowiednikiem byłoby dołączenie skonwertowanego modelu
  CoreML jako zasobu do bundle -- nie zrobione teraz prewencyjnie (dodaje
  złożoność do już niepewnego kodu), ale wiadomo co robić, jeśli się
  powtórzy.
- **Format zwracanego wyniku z `pipe.transcribe()`** -- kod zakłada, że
  zwraca opcjonalną tablicę obiektów z polem `.text`; jeśli aktualna wersja
  API się różni, Xcode zgłosi to jasno przy kompilacji.
- **Minimalny iOS deployment target** -- nie ustawiłem świadomie konkretnej
  wartości, zostaw domyślną z kreatora Xcode; jeśli WhisperKit wymaga
  wyższej wersji niż domyślna, Xcode sam to zgłosi i trzeba będzie podnieść
  "iOS Deployment Target" w ustawieniach projektu.

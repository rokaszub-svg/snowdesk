# Snowdesk — let it snow on your Mac ❄️

Programa gyvena meniu juostoje (be Dock ikonos). Ant ekrano krenta sniegas, kuris kaupiasi ant langų viršaus ir ekrano apačioje. Greitai pajudinus langą, sniegas nukrinta. Iš susikaupusio sniego susirieda gniūžtės, o 🚜 valytuvas nuvalo ekrano apačią. Paspaudimai praeina pro sniegą kiaurai, todėl darbui jis netrukdo.

**Meniu:** Pause / Resume, Stop, Run Snowplow, Shake Snow Off Windows, Clear Snowballs, Clear All Snow, Settings…, Hide Snow for Screenshot (10 s), Quit.
**Nustatymai:** sniego kiekis, greitis, vėjas, snaigių dydis, kaupimasis ir maksimalus gylis, gniūžtės, visi ekranai, paleidimas įsijungus kompiuteriui.

Reikia macOS 13 ar naujesnės. Programa veikia Apple Silicon ir Intel kompiuteriuose. Jokių leidimų (Screen Recording ir pan.) nereikia.

---

## A. Sukompiliuoti per GitHub (Mac nereikia)

1. Susikurk naują GitHub repo ir įkelk šitą aplanką:
   ```bash
   cd Snowdesk
   git init && git add . && git commit -m "Snowdesk 1.0"
   git branch -M main
   git remote add origin https://github.com/TAVO_VARDAS/snowdesk.git
   git push -u origin main
   ```
2. Atsidaryk **Actions → Build macOS app**. Kompiliavimas trunka apie 3 min., o paruoštą `.dmg` rasi skiltyje **Artifacts**.
3. Viešam leidimui sukurk tag'ą:
   ```bash
   git tag v1.0.0 && git push origin v1.0.0
   ```
   Tada `.dmg` atsiras skiltyje **Releases** su viešu parsisiuntimo linku.

## B. Sukompiliuoti savo Mac'e

```bash
xcode-select --install     # vieną kartą
cd Snowdesk
./scripts/build.sh
open dist/Snowdesk.app
```

## Pasirašymas ir notarizacija (būtina viešam platinimui)

Jei programa nepasirašyta, macOS pasakys, kad ji „iš nežinomo kūrėjo“. Žmogus vis tiek gali ją atidaryti per System Settings → Privacy & Security → *Open Anyway*, bet dalis žmonių to nedarys.

Programai pasirašyti reikia Apple Developer paskyros (99 $ per metus).

1. developer.apple.com → Certificates → **+** → **Developer ID Application**. Sertifikatą įsidiek į Keychain ir eksportuok kaip `.p12` su slaptažodžiu.
2. appleid.apple.com → **App-Specific Passwords** → sukurk naują slaptažodį.
3. GitHub repo → Settings → Secrets and variables → Actions → sukurk šiuos secrets:

| Secret | Reikšmė |
|---|---|
| `MACOS_CERT_P12` | `base64 -i cert.p12 \| pbcopy` rezultatas |
| `MACOS_CERT_PASSWORD` | `.p12` slaptažodis |
| `DEVELOPER_ID` | `Developer ID Application: Vardas Pavardė (TEAMID)` |
| `APPLE_ID` | tavo Apple ID el. paštas |
| `APPLE_APP_PASSWORD` | app-specific slaptažodis |
| `APPLE_TEAM_ID` | 10 simbolių Team ID |

Kai secrets nustatyti, kiekvienas build'as automatiškai pasirašomas ir notarizuojamas.

## Pavadinimo keitimas

Pavadinimas ir bundle ID keičiami build metu, kodo keisti nereikia:
```bash
APP_NAME="Sniegas" BUNDLE_ID="lt.tavo.sniegas" VERSION="1.0.0" ./scripts/build.sh
```
Jei build'ini per GitHub, tas pačias reikšmes įrašyk `.github/workflows/build.yml` faile, `Build` žingsnyje. Ikona yra `Resources/AppIcon.png` (1024×1024).

## Struktūra

```
Sources/Snowdesk/
  main.swift            paleidimas, meniu juostos režimas
  AppDelegate.swift     meniu, būsenos, ekranai
  OverlayWindow.swift   permatomas langas, pro kurį praeina paspaudimai
  SnowScene.swift       snaigės, kaupimasis, gniūžtės, valytuvas
  Pile.swift            sniego sluoksnis ant lango krašto
  WindowTracker.swift   atidarytų langų vietos (10 kartų per sekundę)
  Textures.swift        snaigių ir gniūžčių grafika
  Prefs.swift           nustatymai
  SettingsView.swift    nustatymų langas
scripts/build.sh        .app + .dmg (+ pasirašymas ir notarizacija)
```

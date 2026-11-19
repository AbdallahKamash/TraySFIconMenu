# TraySFIconMenu

A lightweight macOS menu bar app that lets you quickly browse, search, and copy SF Symbols without opening the SF Symbols app every time you need an icon for your iOS, iPadOS, macOS, watchOS or visionOS project.

Built with SwiftUI, for macOS only.

![TraySFIconMenu Screenshot](https://repository-images.githubusercontent.com/1128224065/ff9e5187-b6a8-4b62-8e81-e96a8b6e00ee)

## Download

Grab the latest build from the [Releases page](https://github.com/AbdallahKamash/TraySFIconMenu/releases/latest), unzip it, and move `SFIconsTrayMenu.app` to your Applications folder.

> **Beta builds aren't notarized yet.** The first time you open the app, macOS will block it. Right-click the app and choose **Open**, or go to **System Settings → Privacy & Security** and click **Open Anyway**. You only need to do this once.

## Features

- **Lives in your menu bar.** Open it from any app with `⇧⌘T`, or record your own shortcut in Settings (with a one-click reset to the default).
- **The full, current catalog.** Over 8,000 symbols from the latest SF Symbols release, automatically limited to the ones your version of macOS can actually render.
- **Search that understands you.** Search by name, Apple's keywords, or plain words:
  - Numbers by value: `1`, `01`, `one`, `one circle` or `one.circle` all find `01.circle` and `1.circle`.
  - Characters and currencies: `+`, `!`, `%`, `$`, `€`, `dollar`, `euro` …
  - Old names: renamed symbols are found by their legacy names (e.g. `volume` → `speaker`).
- **Inline insert while you code.** In a Swift file in Xcode, VS Code or Cursor, the shortcut opens a small Liquid Glass search right at your text cursor. Type to autocomplete (`Tab` completes, `Return` inserts) and the symbol is typed into your code, with quotes added when needed. `⌥Return` inserts `Image(systemName:)`. Choose the editors, file types, insert style, number of suggestions and more in **Settings → Inline Insert**. Requires Accessibility access, which the welcome tour helps you grant.
- **Browse by category**, using the same categories as Apple's SF Symbols app, including Apple's own **What's New** list.
- **Copy what you need.** Copy the symbol name, or the icon itself as a high-resolution image.
- **Variants at a glance.** Right-click a symbol for its whole family: `.fill`, `.slash`, badges, and localized versions (Arabic, Hindi, right-to-left …).
- **Availability info.** See which macOS and SF Symbols version introduced each symbol.
- **Keyboard first.** Navigate everything without touching the mouse.
- **Welcome tour** on first launch, and a short menu bar animation on later launches so you know where the app went (can be turned off in Settings).
- **Launch at login**, optional.
- **VoiceOver support** for the menu bar icon and the symbol grid.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `⇧⌘T` | Show/hide the symbol browser from any app (change it in Settings → Keyboard Shortcut) |
| Any letter or number | Start typing to search |
| `Tab` | Move focus between search, sidebar, and grid |
| `↑` `↓` `←` `→` | Move around the grid |
| `Return` or `Space` | Copy the selected symbol's name |
| Double-click a symbol | Copy its name |
| `Esc` | Clear the search, then close the browser |
| `⌘C` | Copy the selected symbol's name |
| Right-click a symbol | Copy Name, Copy Icon, Variants, availability |
| Right-click the menu bar icon | Settings, Guide, About, Quit |

**Inline insert** (in a Swift file in Xcode, VS Code or Cursor, after pressing the shortcut):

| Key | Action |
|-----|--------|
| Type | Search, with the top match completed in grey |
| `Tab` | Accept the grey completion |
| `↑` `↓` | Choose a suggestion |
| `Return` | Insert (format set in Settings → Inline Insert) |
| `⌥Return` | Insert the alternative format, e.g. `Image(systemName: "star.fill")` |
| `Esc` | Close without inserting |

## Requirements

- **To run:** macOS 26.0 or later
- **To build:** Xcode 26.2 or later

## Building from Source

1. Clone the repository
   ```bash
   git clone https://github.com/AbdallahKamash/TraySFIconMenu.git
   cd TraySFIconMenu
   ```
2. Open the project in Xcode
   ```bash
   open SFIconsTrayMenu.xcodeproj
   ```
3. Build and run with `⌘R`. To run the unit tests, press `⌘U`, or from the terminal:
   ```bash
   xcodebuild -project SFIconsTrayMenu.xcodeproj -scheme SFIconsTrayMenu test
   ```

The only dependency, [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern), is fetched automatically by Swift Package Manager.

### Project Structure

| Path | What's inside |
|------|---------------|
| `SFIconsTrayMenu/AppDelegate.swift` | Menu bar item, popover, windows, launch flow |
| `SFIconsTrayMenu/SymbolBrowserView.swift` | The main symbol browser (sidebar, search, grid) |
| `SFIconsTrayMenu/SymbolCategory.swift` | Loads and caches the bundled SF Symbols metadata |
| `SFIconsTrayMenu/SymbolSynonyms.swift` | Search: synonyms, number words, ranking |
| `SFIconsTrayMenu/HotKeyManager.swift` | Global shortcut registration and storage |
| `SFIconsTrayMenu/ShortcutRecorder.swift` | The shortcut recorder in Settings |
| `SFIconsTrayMenu/OnboardingView.swift` | First-launch welcome tour |
| `SFIconsTrayMenu/LaunchOverlay.swift` | The menu bar launch animation |
| `SFIconsTrayMenu/AboutView.swift` | The About window |
| `SFIconsTrayMenuTests/` | Unit tests (Swift Testing) |

## Data Source

The symbol data comes from the metadata inside Apple's SF Symbols app, bundled with TraySFIconMenu:

- Symbol names and the release that introduced each one (`name_availability.plist`), used to hide symbols your macOS version can't render
- Categories, including Apple's own "What's New" list (`categories.plist`, `symbol_categories.plist`)
- Search keywords plus current and legacy (renamed) names (`symbol_search.plist`, `name_aliases.strings`, `legacy_aliases.strings`)
- Symbol variant families such as `.fill`, `.slash` and localized versions (`base_symbols_map.json`)

To update to a newer SF Symbols release, copy the files from `/Applications/SF Symbols.app/Contents/Resources/Metadata/` into `SFIconsTrayMenu/` and rebuild.

## Privacy

TraySFIconMenu works completely offline. It doesn't collect, store, or send any data. The only time it touches the internet is when you click a link in the About window.

Inline insert uses macOS Accessibility access only to find your text cursor, read the name of the open file, and type the chosen symbol. Because macOS doesn't allow this inside the App Sandbox, the app is not sandboxed.

## Acknowledgments

- Apple for the incredible SF Symbols library
- [Sindre Sorhus](https://github.com/sindresorhus) for LaunchAtLogin-Modern
- The SwiftUI community for inspiration and best practices

## Support

If you find this app useful, please consider starring the repository, sharing it on Twitter (@arceus_kmsh), or contributing code or documentation. Found a bug or have an idea? [Open an issue](https://github.com/AbdallahKamash/TraySFIconMenu/issues).

---

**Note:** SF Symbols are provided by Apple and are subject to Apple's license terms. TraySFIconMenu is an independent project and is not affiliated with Apple.

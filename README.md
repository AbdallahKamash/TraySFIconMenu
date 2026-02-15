# TraySFIconMenu

A lightweight macOS menu bar app that lets you quickly browse, search, and copy SF Symbols to your clipboard without the need to open the SF Symbol everytime you
want an icon for your iOS/iPadOS/macOS project.

. Built with SwiftUI for macOS only.

![TraySFIconMenu Screenshot](https://repository-images.githubusercontent.com/1128224065/ff9e5187-b6a8-4b62-8e81-e96a8b6e00ee)

## Features

- **Menu Bar Integration** - Lives in your menu bar for quick access (keyboard shortcut `Shift`+`⌘T`)
- **Powerful Search** - Search by symbol name, keywords, or aliases (0 = zero, 123 = numbers, a = character, etc...)
- **Categorized Browsing** - Browse symbols by categories including "What's New"
- **Full Keyboard Navigation** - Navigate entirely without a mouse
- **One-Click Copy** - Click any symbol to copy its name to clipboard with Toast notifications when symbols are copied

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Tab` | Move focus between search, sidebar, and grid |
| `↑/↓/←/→` | Navigate symbols in grid view |
| `Enter` or `Space` | Copy selected symbol |
| `⌘C` | Copy selected symbol |
| Any alphanumeric key | Start typing to search (when in grid) |
| `Tab` from grid | Return to search field |

## Installation

### Requirements
- macOS 13.0+ (Ventura or later) - "built with macOS 26.3"
- Xcode 15.0+ - "built with Xcode 26.2"
- Swift 5.9+ - "built with Swift 6.2"

### Steps
1. Clone the repository
```bash
git clone https://github.com/AbdallahKamash/TraySFIconMenu.git
cd TraySFIconMenu
```

2. Open in Xcode
```bash
open TraySFIconMenu.xcodeproj
```

3. Build and run (⌘R)

## How It Works

TraySFIconMenu loads the complete SF Symbols catalog and organizes them into categories. The app includes:

- **All Symbols** - Complete SF Symbols library (latest)
- **Category Filters** - Organized by Apple's predefined categories to make the user more familiar with the already existing layout of the official SF Symbol App.
- **Smart Search** - Includes symbol aliases and keywords for better discovery

The app runs as a menu bar application with a small memory footprint, making it perfect for designers and developers who frequently need to reference or copy SF Symbol names.

## Data Source

The symbol data is loaded from Apple's SF Symbols app bundle, including:
- Symbol names and categories
- Layer set information (which SF Symbols version introduced each symbol)
- Search keywords and aliases for better discoverability

## Acknowledgments

- Apple for the incredible SF Symbols library
- The SwiftUI community for inspiration and best practices

## Support

If you find this app useful, please consider:
Starring the repository, sharing on Twitter (@arceus_kmsh), or contributing code or documentation

---

**Note:** This app requires SF Symbols, which is part of Xcode and macOS. Make sure you have the latest Xcode installed or macOS Ventura or later for the best experience.

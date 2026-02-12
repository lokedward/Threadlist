# Threadlist: Digital Studio & Wardrobe

**Threadlist** is a premium, AI-powered personal wardrobe management application for iOS. Designed with a "High-End Boutique" (Posh) aesthetic, it transforms the way you organize your closet and visualize your personal style.

---

## ✨ Core Features

### 🏛️ The Studio (AI Stylist)
The centerpiece of Threadlist. Leverage **Google Gemini 2.5 Flash** to analyze your real clothing items and generate high-fidelity, editorial-style fashion photos.
- **Visual Intelligence**: Analyzes fabric, texture, color, and fit of selected garments.
- **Multimodal Generation**: Creates and caches realistic model photos of your specific outfit combinations.
- **Pinch-to-Zoom**: Examine every detail of your AI-generated looks with intuitive gesture controls.
- **Intelligent Caching**: Local persistence of outfit descriptions and images to minimize API latency and costs.

### 📧 Smart Email Import
Automate your digital wardrobe building by connecting your GMail account.
- **Automated Collection**: Scans order confirmations from top retailers (Nordstrom, Nike, ASOS, Zara, and more).
- **Intelligent Parsing**: Extracts product names, brands, sizes, and high-resolution images using custom Google Apps Script integration.
- **Generic Fallback**: Robust parsing logic to identify products from unknown brands by looking for contextual price and image clues.

### 📂 "Draft Your Closet" Onboarding
A premium first-time experience that eliminates the "blank canvas" problem.
- **Shadow Shelves**: Visual placeholders that show you exactly how your wardrobe will be organized before you even add an item.
- **Seasonal Templates**: One-tap "Starter Capsules" (Winter Essentials, Weekend Edit, Minimalist) to instantly populate your category structure.
- **Boutique UI**: A cohesive design system utilizing warm stone tones, serif typography, and elegant card-based layouts.

### 🛡️ Privacy & Performance
- **Local-First Architecture**: Powered by **SwiftData** for secure, on-device metadata storage.
- **Secure Image Handling**: Photos are stored locally in the app's sandboxed Documents directory.
- **Off-Main-Actor Processing**: Heavy image resizing and analysis tasks are handled on detachment tasks to keep the UI fluid and responsive.

---

## 🛠️ Tech Stack

- **UI Framework**: SwiftUI
- **Data Layer**: SwiftData (Local Persistence)
- **AI Engine**: Google Gemini API (`gemini-2.5-flash` & `gemini-2.5-flash-image`)
- **Integration**: Google Apps Script (Email Parsing API)
- **Networking**: URLSession with custom multimodal request builders
- **Security**: CryptoKit for stable SHA256 caching keys

---

## 🗺️ Roadmap & Current State

### **Current Phase: UI Polish & Stability (MVP+)**
- [x] **Posh Design System**: Implementation of the signature boutique aesthetic.
- [x] **AI Caching Layer**: Persistent storage for generated outfits.
- [x] **Bulk Management**: "Skip" and "Abort" logic for large-scale closet digitization.
- [x] **Interactive Studio**: Zoomable, high-res model photo generation.

### **Future: Next Steps**
- [ ] **Smart Outfit Recommendations**: Proactive AI suggestions based on the current weather and your calendar events.
- [ ] **Community Showroom**: Opt-in sharing of generated looks to a curated community feed.
- [ ] **Advanced Analytics**: "Cost-per-wear" tracking and wardrobe utility heatmaps.
- [ ] **Multi-Device Sync**: Optional iCloud synchronization for wardrobe access across iPhone and iPad.

---

## 🚀 Getting Started

1. **API Keys**: Add your Gemini API Key to `AppConfig.swift`.
2. **Permissions**: Ensure Camera and Photo Library access are granted.
3. **Studio Access**: Navigate to the "Studio" tab to begin generating your first looks.

---

*Threadlist is more than a tracker; it's your personal fashion atelier.*

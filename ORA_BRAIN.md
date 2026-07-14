# ORA PROJECT BRAIN
**Last updated:** July 10, 2026 — Load this at the start of every session.

---

## 1. Project Identity

| Field | Value |
|---|---|
| **App name** | Ora (formerly Lumen — renamed June 2026 due to Lumen Technologies trademark) |
| **Bundle ID** | `com.donsnotes.app` |
| **App ID (ASC)** | `6777510925` |
| **Display name** | `Ora` (set via `PRODUCT_NAME = Ora` in project.pbxproj) |
| **GitHub repo** | https://github.com/dkgrissom-tech/Dons-notes |
| **Local clone** | `/tmp/Dons-notes-work/` |
| **TestFlight** | https://testflight.apple.com/join/5YckE6M7 |
| **Current build** | 96 |
| **Trigger word** | `"ora"` — say it mid-meeting to activate AI |
| **AI voice** | Daniel (ElevenLabs) — British male |
| **AI backend** | Groq `llama-3.3-70b-versatile` — FREE for all users, zero cost per user |

---

## 2. Apple Developer Credentials

| Field | Value |
|---|---|
| **Apple ID** | dkgrissom@gmail.com |
| **Team ID** | `7L4H4W3H94` |
| **App Store Connect API Key ID** | `N8C8H25PK2` |
| **Issuer ID** | `872fbdda-59aa-4746-8d08-e6c566d1f8f9` |
| **Private Key (ES256 DER base64)** | `[PRIVATE_KEY — stored in GitHub Secret APP_STORE_CONNECT_API_KEY]` |
| **Internal TestFlight group ID** | `aca5f162-a25f-4d25-ba57-165c98b1aa55` |
| **External TestFlight group ID** | `03dff58c-e0bd-4276-b720-5fcd9dfde010` |

---

## 3. API Keys

| Service | Key | Notes |
|---|---|---|
| **Groq** | `[GROQ_KEY — stored in GitHub Secret GROQ_API_KEY]` | Free tier, replaces Anthropic — zero user cost |
| **Groq model** | `llama-3.3-70b-versatile` | Set in Config.swift + GitHub Secrets |
| **ElevenLabs** | `[ELEVENLABS_KEY — stored in GitHub Secret ELEVENLABS_API_KEY]` | |
| **ElevenLabs Voice ID** | `onwK4e9ZLuTAKqWW03F9` | Daniel, British male |
| **Anthropic** | REMOVED — was burning user coins. Never add back to client. | |

---

## 4. CI/CD Pipeline

| Field | Value |
|---|---|
| **Workflow file** | `/.github/workflows/build.yml` (repo root) |
| **Runner** | `macos-15`, `Xcode_26.3.app` |
| **Fastfile location** | `donsnotes-ios/MinimalProject/fastlane/Fastfile` |
| **Upload lane name** | `beta` (NOT `appstore` or `release` for TestFlight builds) |
| **App Store submit lane** | `release` — triggered by git tag `v*.*.*-release` only |
| **xcargs includes** | `ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_ID`, `GROQ_API_KEY` |
| **Trigger** | Push to `master` |
| **Build number** | Fastlane auto-increments CFBundleVersion from latest ASC build — git commit numbers and ASC numbers WILL diverge. This is normal. |

### Post-upload checklist — NOW FULLY AUTOMATED (Build 91+)
The Fastfile `beta` lane handles all post-upload steps automatically after every CI build:
1. Generates ASC JWT from GitHub Secrets (`APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY`) via PyJWT step in workflow
2. Polls ASC every 30s (up to 10 min) until build appears as `VALID`
3. `PATCH /v1/builds/{id}` → `usesNonExemptEncryption=false` (clears export compliance — 409=already set, that's fine)
4. `POST betaGroups/aca5f162.../relationships/builds` → internal group
5. `POST betaGroups/03dff58c.../relationships/builds` → external group

**No manual App Store Connect steps needed after a push. Fully hands-off.**

---

## 5. Key Source Files

```
/tmp/Dons-notes-work/donsnotes-ios/MinimalProject/DonsNotes/
├── Sources/
│   ├── Config.swift                    — groqKey, groqModel, elevenLabsKey
│   ├── DonsNotesApp.swift              — app entry, @AppStorage("hasSeenOnboarding") gate
│   ├── LUMENDesignSystem.swift         — design system (class names kept LUMEN* internally)
│   ├── Services/
│   │   ├── SpeechRecognizerService.swift  — owns AVAudioSession exclusively
│   │   │                                    AVAudioSession category: .playAndRecord
│   │   │                                    mode: .measurement, options: .duckOthers
│   │   ├── LUMENService.swift             — silenceWaitSeconds=2.5, Groq via askGroq()
│   │   ├── SubscriptionService.swift      — isOwner bypass, canUseOraAI, .oraPro tier
│   │   ├── ReferralService.swift
│   │   └── RealAPIService.swift           — X-Owner-Bypass header, askAI() method
│   └── Views/
│       ├── RecordingView.swift         — dual mic buttons (name + email), FocusState
│       │                                 Build 91: CTCallCenter monitor, phoneCallBannerVisible
│       ├── LUMENOrbView.swift          — label shows "ORA"
│       ├── MeetingListView.swift       — NO onboarding here (removed Build 48)
│       ├── ProfileView.swift           — dev bypass: tap header 3x → toggle
│       ├── PlansView.swift             — long press 1.5s to reveal bypass
│       ├── MeetingDetailView.swift     — "Summary Sent!" confirmation
│       └── OnboardingView.swift        — "Meet ORA", "just say Ora"
└── Resources/
    └── Assets.xcassets/
        └── AppIcon.appiconset/         — ← CORRECT icon location (not Sources/Assets.xcassets!)
```

---

## 6. Complete Build History

| Build | What changed | Result | Key lesson |
|---|---|---|---|
| 28 | Mic permission (AVAudioApplication→AVAudioSession), Jarvis ring scaling, dormant opacity, session conflict | ✅ | AVAudioApplication deprecated |
| 29 | Name→Email keyboard focus (FocusState, submitLabel) | ✅ | |
| 30 | Second mic button on email field, strips spaces+lowercases email | ✅ | |
| 31 | Dev full-access bypass toggle (tap header 5x in Profile) | ✅ | |
| 32 | Fix dev bypass @ObservedObject reactivity, "Summary Sent!" email confirmation | ✅ | |
| 33 | X-Owner-Bypass + X-Subscription-Tier headers on all API calls | ✅ | |
| 34 | UserDefaults fallback in canUseOraAI, PlansView auto-reveals bypass, tap threshold 5→3 | ✅ | |
| 35 | Surface real Claude error messages | ✅ | Revealed Anthropic out of credits |
| 36 | Groq swap attempt | ❌ | Swift 6: no DispatchQueue.main.async |
| 37 | Fix concurrency | ❌ | Task @MainActor [weak self] placement wrong |
| 38 | Fix same | ❌ | Same issue on another line |
| 39 | MockAPIService conformance fix; Groq swap complete | ✅ | Free AI for all users |
| 40 | Lumen→Ora rename | ❌ | SubscriptionTier missing .oraPro (PricingPlan.swift missed) |
| 41 | Fixed enum, full rename live | ✅ | grep ALL files when renaming enums |
| 42 | Silence timeout 1.2s→2.5s | ✅ | |
| 43 | New Ora orb icon (1024x1024) | ❌ icon | Copied to WRONG xcassets folder |
| 44 | Fix PRODUCT_NAME=Ora (was DonsNotes target name) | ✅ | TestFlight uses binary name not CFBundleDisplayName |
| 45 | Fix alreadyTriggered never resetting; broaden orbTapped guard | ✅ | Ora only answered once per session |
| 46 | Icon to correct xcassets; StoreKit crash-safe; IAP ID orapro | ❌ | Conflicting icon-1024.png (lowercase) caused 409 on upload |
| 47 | Remove old icon-1024.png | ❌ CI | Build 48 pushed before 47 confirmed |
| 48 | Fix crash: remove duplicate onboarding in MeetingListView | ✅ | Two onboarding systems fought → crash |
| 91 | Phone call interruption detection + auto-resume + automated post-upload pipeline | ✅ | See lessons 18–20 below |

---

## 7. Critical Build Lessons (never repeat)

1. `Info.plist` uses `$(CURRENT_PROJECT_VERSION)` / `$(MARKETING_VERSION)` — NEVER hardcode
2. `SubscriptionService` must NOT be `@MainActor` — LUMENService reads from nonisolated context
3. `SpeechRecognizerService` owns AVAudioSession exclusively — category: `.playAndRecord`, mode: `.measurement`, options: `.duckOthers`
4. `removeTap(onBus: 0)` unconditional before `installTap`
5. `orbState = .listening` set BEFORE `speechService.startListening()`
6. **TimelineView `@ViewBuilder`: NO `let` bindings** — use OrbFrame struct
7. `.onChange(of:)` must use `{ _, newValue in }` syntax (Xcode 26)
8. Trigger word is `"ora"` (single word, lowercase)
9. Fastlane App Store lane is named `release` not `appstore`
10. Post-upload steps (export compliance + TestFlight groups) are now automated in the Fastfile beta lane — do NOT run manually
11. **Swift 6**: No `DispatchQueue.main.async` — use `Task { @MainActor in }` with `[weak self]` at closure start
12. When renaming enum cases, grep ALL files — sed misses model files
13. MockAPIService must implement ALL protocol methods or CI fails
14. **Icon files go in `Resources/Assets.xcassets/AppIcon.appiconset/`** — NOT `Assets.xcassets/`
15. **One onboarding system only** — `DonsNotesApp` is the gate via `@AppStorage("hasSeenOnboarding")`
16. **Fastlane auto-increments CFBundleVersion from ASC** — git build numbers and ASC build numbers will diverge
17. User must delete + reinstall from TestFlight to get new icon (iOS icon cache doesn't update on OTA)
18. **Cellular call interruptions do NOT include `.shouldResume`** — `AVAudioSession.interruptionNotification` alone will never auto-resume after a phone call. Use `CTCallCenter.callEventHandler` for cellular call detection and recovery.
19. **`CTCallCenter.callEventHandler` fires on a background thread** — always dispatch to `@MainActor` via `Task { @MainActor in }` before touching any `@State` or UI.
20. **Post-upload pipeline is fully automated as of Build 91** — the Fastfile beta lane polls ASC, sets export compliance, and adds to both TestFlight groups. The workflow generates the ASC JWT via PyJWT from GitHub Secrets. No manual ASC steps ever needed again.

---

## 8. Known Bugs & Current Status

### Current build: 96

**Build 96 (July 13, 2026) — High-Value Feature Drop:**
- **Ask Ora (cross-meeting memory)** — Brain icon in toolbar opens `AskOraView`. Searches across all completed meetings using Groq llama-3.3-70b. Includes suggested prompts, conversation history, and per-turn answers. New file: `Sources/Views/AskOraView.swift`.
- **Pre-meeting brief** — When attendees are added (via quick-add, manual, or repeat meeting), Ora automatically looks up the most recent past meeting those attendees were in and shows a collapsible card with the date, summary snippet, and open action items. Updates live as attendees change.
- **Draft Follow-Up Email** — New "Draft Follow-Up Email" button (wand icon) in MeetingDetailView action buttons. Appears only when action items exist. Uses Groq to write a professional follow-up email (~200 words), then opens Mail/share sheet with To: pre-populated from attendee emails. Falls back to plain text share if Groq fails.

### Build 91
- **Phone call interruption** — Fixed in B91. CTCallCenter monitors cellular calls. Banner shown when call active. Auto-resumes 0.8s after call ends.
- **Silent fail on cellular calls** — Fixed in B91. Previously: iOS killed audio session with no user feedback. Now: banner + auto-resume.

### Fixed (history)
- Ora only answered once per session (alreadyTriggered never reset) — fixed B45
- App name showed "DonsNotes" in TestFlight — fixed B44 (PRODUCT_NAME=Ora)
- Groq free AI for all users — fixed B39
- Dev bypass for testing Pro features — fixed B34
- Crash after intro (duplicate onboarding) — fixed B48

---

## 9. Subscription & IAP

| Product ID | Name | Price | Status |
|---|---|---|---|
| `com.donsnotes.app.pro.monthly` | Pro Monthly | $12.99 | NOT YET CREATED in ASC |
| `com.donsnotes.app.orapro.monthly` | Ora Pro Monthly | $19.99 | NOT YET CREATED in ASC |
| `com.donsnotes.app.lifetime` | Lifetime Access | $149 | NOT YET CREATED in ASC |

**Dev bypass:** In Profile screen, tap the header 3 times → toggles full Pro access. In PlansView, long press 1.5s.

---

## 10. Marketing Assets (all files in /home/user/workspace/)

| File | Contents |
|---|---|
| `ORA_TEASE_CAMPAIGN.md` | 6 TikTok video scripts, @meetora, June 22 – July 27 |
| `ORA_MARKETING_COPY.md` | 5 hunter DMs, LinkedIn post, 3 Reddit posts, beta email |
| `ORA_LAUNCH_ASSETS.md` | Product Hunt copy, IAP setup, Zara demo script |
| `ORA_LAUNCH_PLAYBOOK.md` | Full launch order: Phase 0→4, dates, checklists |
| `ora_app_icon_1024.png` | New glowing cyan orb icon |

### Launch plan summary
- **June 22:** Create @meetora TikTok + Instagram, post Video 1 (mystery teaser)
- **June 22 – July 27:** 6-video teaser campaign, one per week
- **July 27:** App Store public launch, Reddit posts, LinkedIn, email beta testers
- **August 3:** Product Hunt launch (1 week after App Store)

---

## 11. Trademark Status

| Name | Status |
|---|---|
| Lumen | ❌ Lumen Technologies owns Class 9+42 |
| Lucid | ❌ Lucid Software Inc. |
| Ora | ✅ Clean — using common law ™ (no USPTO filing yet) |
| Oryn | ✅ Clean (backup) |
| Sovra | ✅ Clean (backup) |

---

## 12. User Preferences (critical — never violate)

- **Maximum automation** — "I want to make this as automated as possible so I only have to touch when absolutely necessary!!"
- **Never loop** — "Stop you're wasting all my coins" — find alternative immediately if something fails twice
- **No API key friction** — "So sick of API Bs!! Don't use I've wasted more $ and time on stupid api keys"
- **No Anthropic/paid AI on client** — "I don't want customers using my coins ever!!"
- **Agent makes decisions** — "You pick for what you need"
- **Test before sending** — "Take your time and test before sending"
- **No unrequested features** — "I didn't ask for that"
- **Quality bar is high** — "I want an out of the box app that blows people away"
- **Save state always** — "Save your spot to memory" — always save session state at end

---

## 13. Other Projects (don't confuse with Ora)

- **Jarvis** — Desktop Windows voice assistant, published at https://jarvis-don.pplx.app (Site ID: `1df53f76-86f6-4c08-97f6-be2a83022857`)
- **Zara** — AI influencer/avatar for Ora marketing. TikTok: @meetora
- **Dons-Notes Android** — Cross-platform note-taking, in `/tmp/Dons-notes-work/donsnotes-android/`
- **Adult coloring books** — Gumroad/Etsy/Amazon KDP revenue sprint ($3k by July 7)
- **Kids comic/coloring book app** — Web demo planned
- **Future apps** — Subscription Tracker → AI Habit Tracker → Meal Plan app

---

## 14. Revenue Goal

**1,000 Ora Pro subscribers ($19.99/mo) by Christmas 2026 = $20k MRR**
- 100 users by Oct 1
- 500 users by Nov 15
- 1,000 users by Dec 25

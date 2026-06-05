# GitHub Secrets Setup — iOS Signed Builds & TestFlight

This is the **one-time setup** that makes the `ios-testflight.yml` workflow work.
Once these secrets are in place, every push to `main` automatically builds, signs,
and uploads to TestFlight. No Mac required.

> **Time budget:** ~45 minutes total, broken into three phases below.
> Do this in order — each phase produces values needed by the next.

---

## Phase 1 — Apple Developer Program (24–48 hour wait)

> Start this **first** so it can be approving in the background while you do Phase 2 & 3.

1. Go to <https://developer.apple.com/programs/enroll/>
2. Sign in with your existing Apple ID (turn on 2FA if you haven't already)
3. Choose **Individual / Sole Proprietor** (skips the D-U-N-S Number requirement that blocks organizations)
4. Use your **legal name** — nicknames cause approval delays
5. Pay the $99 enrollment fee
6. **Wait 24–48 hours for Apple to approve.** You'll get an email when ready.

Once approved, grab your **Team ID**:
- <https://developer.apple.com/account> → **Membership details** → "Team ID" (10 characters, e.g. `A1B2C3D4E5`)

---

## Phase 2 — Register the App ID + create the App Store Connect API key

After Phase 1 is approved:

### 2a. Register the bundle ID

1. <https://developer.apple.com/account/resources/identifiers/list> → **+**
2. Pick **App IDs** → **App**
3. Description: `Don's Notes`
4. Bundle ID: **Explicit** → `com.donsnotes.app`
5. Capabilities: leave defaults (you can add Push Notifications later)
6. **Continue → Register**

### 2b. Create the app in App Store Connect

1. <https://appstoreconnect.apple.com/apps> → **+** → **New App**
2. Platform: iOS
3. Name: `Don's Notes`
4. Primary language: English (U.S.)
5. Bundle ID: select `com.donsnotes.app`
6. SKU: `dons-notes-ios` (just an internal ID, anything unique works)
7. **Create**

### 2c. Generate the App Store Connect API key

> Use desktop browser — the mobile App Store Connect UI is buggy for key creation.

1. <https://appstoreconnect.apple.com/access/integrations/api> → **Team Keys** → **+**
2. Name: `GitHub Actions CI`
3. Access: **App Manager** (minimum required for TestFlight uploads)
4. **Generate**
5. Click **Download API Key** — you get an `AuthKey_XXXXXXXXXX.p8` file
   - ⚠️ **This is the only time it can be downloaded. Save it carefully.**
6. From that page, also note:
   - **Issuer ID** (UUID format, shown at the top of the page)
   - **Key ID** (10 characters, in the row of your new key)

---

## Phase 3 — Set up the `match` certificate repo (cert sync for CI)

`fastlane match` keeps your distribution certificate + provisioning profile in a
**separate private GitHub repo**, encrypted with a passphrase. CI clones that repo
on every build to install the cert into a temporary keychain.

### 3a. Create the storage repo

1. <https://github.com/new>
2. Repository name: `donsnotes-certificates`
3. **Private** (critical — this holds your signing keys)
4. Don't initialize with anything (no README, no .gitignore)
5. Create

### 3b. Seed the repo with your cert + profile (one-time, requires a Mac)

This is the **only step that needs a Mac, ever**. After this, all CI builds work from Windows/Linux.

Options if you don't have a Mac:
- **GitHub Codespaces with macOS** isn't available, but you can use **MacStadium**, **MacInCloud**, or borrow a friend's Mac for 30 minutes
- Or run the setup once on a free trial of a cloud Mac service

On the Mac, with the repo cloned:
```bash
cd Dons-notes/donsnotes-ios
bundle install
bundle exec fastlane match appstore \
  --git_url https://github.com/dkgrissom-tech/donsnotes-certificates \
  --app_identifier com.donsnotes.app
```

It will:
- Prompt for an encryption passphrase → **save this, it goes into GitHub Secrets as `MATCH_PASSWORD`**
- Sign in to your Apple Developer account → creates a new distribution cert
- Generate a provisioning profile for `com.donsnotes.app`
- Push everything encrypted to your `donsnotes-certificates` repo

### 3c. Create a Personal Access Token for CI to read the cert repo

1. <https://github.com/settings/tokens/new> → "Fine-grained token"
2. Name: `donsnotes-certificates-readonly`
3. Expiration: 1 year
4. Repository access: **Only select repositories** → `donsnotes-certificates`
5. Permissions → Repository → **Contents: Read**
6. **Generate** and copy the `github_pat_...` token

Now base64-encode `username:token` for the `MATCH_GIT_BASIC_AUTHORIZATION` secret:
```bash
echo -n "dkgrissom-tech:github_pat_YOURTOKEN" | base64
```

---

## Phase 4 — Add all secrets to GitHub

Go to <https://github.com/dkgrissom-tech/Dons-notes/settings/secrets/actions> and add:

| Secret name                       | Value                                                                                                    | Source                       |
|-----------------------------------|----------------------------------------------------------------------------------------------------------|------------------------------|
| `APPLE_ID`                        | Your Apple Developer account email                                                                       | Phase 1                      |
| `APPLE_TEAM_ID`                   | 10-character Team ID (e.g. `A1B2C3D4E5`)                                                                 | Phase 1, Membership page     |
| `APP_STORE_CONNECT_KEY_ID`        | 10-character Key ID                                                                                      | Phase 2c                     |
| `APP_STORE_CONNECT_ISSUER_ID`     | UUID                                                                                                     | Phase 2c                     |
| `APP_STORE_CONNECT_KEY_CONTENT`   | Base64 of the `.p8` file: `base64 -i AuthKey_XXXXXXXXXX.p8` (Mac) or `base64 -w0 AuthKey_*.p8` (Linux)  | Phase 2c                     |
| `MATCH_GIT_URL`                   | `https://github.com/dkgrissom-tech/donsnotes-certificates`                                               | Phase 3a                     |
| `MATCH_PASSWORD`                  | The passphrase you set when running `fastlane match`                                                     | Phase 3b                     |
| `MATCH_GIT_BASIC_AUTHORIZATION`   | The base64 string from Phase 3c                                                                          | Phase 3c                     |
| `MATCH_KEYCHAIN_PASSWORD`         | Any random string (e.g. `openssl rand -base64 32`) — used to encrypt the temporary CI keychain          | Generate yourself            |

---

## Phase 5 — Test it

1. Push any commit to `main` (or click **Run workflow** on the **iOS · Signed build → TestFlight** workflow in the Actions tab)
2. Watch the build at <https://github.com/dkgrissom-tech/Dons-notes/actions>
3. On success, the build appears in App Store Connect → TestFlight within ~10 minutes (Apple processing time)
4. Add yourself as an internal tester at <https://appstoreconnect.apple.com> → My Apps → Don's Notes → TestFlight → Internal Testing
5. Install the **TestFlight** app on your iPhone from the App Store
6. Open the email invite from Apple → tap "View in TestFlight" → install Don's Notes 🎉

---

## Troubleshooting

| Error                                                            | Fix                                                                                            |
|------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| `No profiles for 'com.donsnotes.app' were found`                 | Run Phase 3b again with `--force` to regenerate                                                |
| `Authentication failed for App Store Connect API`                | Re-base64 the `.p8` file with no line wrapping: `base64 -w0` on Linux                          |
| `Could not connect to git@github.com:.../donsnotes-certificates` | Check `MATCH_GIT_BASIC_AUTHORIZATION` — must be base64 of `username:pat`, no spaces            |
| `Build number must be greater than the current build number`     | Auto-handled by `increment_build_number` in the Fastfile — if it still fires, bump manually in App Store Connect |
| `Provisioning profile doesn't include signing certificate`       | Cert and profile got out of sync — re-run `fastlane match appstore --force`                    |

---

## What this gives you

- ✅ Push to `main` → app on your iPhone in ~15 minutes, every time
- ✅ Real signed builds, not 7-day-expiring sideloads
- ✅ Distribute to up to 100 internal testers + 10,000 external testers via TestFlight
- ✅ App Store submission is `fastlane release` away
- ✅ Zero Apple ID passwords in CI — only the API key, which can be revoked any time

The `ios-unsigned.yml` workflow is kept as a fallback for AltStore/Sideloadly distribution if you ever need a build without going through TestFlight.

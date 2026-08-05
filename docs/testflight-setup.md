# Getting Exhale onto TestFlight

Everything here needs your Apple Developer account, so none of it could be done
overnight. It's about ten minutes of your time, and then the Build workflow can
ship on its own from that point forward.

**No key ever gets pasted into a chat.** Every secret goes in via `gh secret set`
reading from a file, so the value never appears on screen or in shell history.

---

## 1. Register the app (App Store Connect, ~3 min)

1. <https://developer.apple.com/account/resources/identifiers> → **+** →
   App IDs → App. Bundle ID: `com.matthias1412.exhale`, description "Exhale".
   Capabilities: nothing extra — the app needs no entitlements beyond the
   default. Push is *not* required; notifications are local only.
2. <https://appstoreconnect.apple.com/apps> → **+** → New App.
   - Platform: iOS
   - Name: `Exhale — Quit Nicotine`
   - Primary language: English (UK)
   - Bundle ID: the one above
   - SKU: `exhale-ios`
3. Note your **Team ID** from
   <https://developer.apple.com/account> (top right, ten characters).

## 2. Create an App Store Connect API key (~2 min)

<https://appstoreconnect.apple.com/access/integrations/api> → **+**

- Name: `Exhale CI`
- Access: **App Manager**

Download the `.p8`. **It can only be downloaded once.** Note the Key ID and the
Issuer ID shown on that page.

## 3. Set the secrets (~2 min)

Run these from the repo. The `.p8` is read from disk, never typed:

```bash
gh secret set APP_STORE_CONNECT_KEY < ~/Downloads/AuthKey_XXXXXXXXXX.p8
```

```bash
echo -n "YOUR_KEY_ID" | gh secret set APP_STORE_CONNECT_KEY_ID
```

```bash
echo -n "YOUR_ISSUER_ID" | gh secret set APP_STORE_CONNECT_ISSUER_ID
```

```bash
echo -n "YOUR_TEAM_ID" | gh secret set DEVELOPMENT_TEAM
```

Then a passphrase for the encrypted certificates branch — pick anything long,
store it in your password manager:

```bash
echo -n "YOUR_MATCH_PASSPHRASE" | gh secret set MATCH_PASSWORD
```

```bash
gh secret set MATCH_GIT_BASIC_AUTHORIZATION --body "$(printf 'matthias1412:%s' "$(gh auth token)" | base64)"
```

## 4. Create the signing certificates once (~2 min)

`match` needs to generate and encrypt the certificates the first time, and that
has to happen on a machine signed in to your Apple ID — so it's one command
from a Mac, *or* let CI do it by temporarily flipping `readonly` off in
`fastlane/Matchfile`. Easiest path if you have no Mac:

```bash
gh workflow run build.yml -f tests=false -f testflight=true
```

If it fails on signing, tell me the error and I'll adjust the lane — this is the
one step I can't fully predict without seeing your account's existing
certificates.

## 5. Ship

```bash
gh workflow run build.yml -f tests=true -f testflight=true
```

Roughly 8–10 minutes, then it appears in TestFlight. Processing on Apple's side
usually takes another 5–15.

---

## RevenueCat (needed before the paywall does anything real)

The app currently runs on `MockSubscriptionGate`, and the paywall honestly
reports "Subscriptions are not configured yet" rather than showing invented
prices. To make it real:

1. In RevenueCat, add a new app for bundle `com.matthias1412.exhale`.
2. Create two products matching App Store Connect:
   - `exhale.yearly` — 1 year, with a 7-day free trial
   - `exhale.monthly` — 1 month
3. Put them in an entitlement called **`premium`** (the identifier the code
   expects) and attach them to an offering.
4. Give me the **public** SDK key (`appl_…`) — that one is safe to hold in the
   app binary, but I'll still set it as a secret rather than commit it:

```bash
echo -n "appl_YOURKEY" | gh secret set REVENUECAT_KEY
```

Two things worth knowing before you price it:

- **A first subscription must be submitted together with a new app version**,
  and each subscription needs its own review screenshot.
- Prices come from the store, localised. Nothing in the app converts currency,
  and the paywall's "pays for itself in N days" line hides itself when the
  store's currency differs from the one you priced your habit in.

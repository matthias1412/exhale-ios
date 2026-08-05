# App Store Connect — what exists

Set up on 5 Aug 2026. Real identifiers, so nothing here needs guessing later.

| Thing | Value |
|---|---|
| Team ID | `5V34CH99XU` (now in the `DEVELOPMENT_TEAM` secret) |
| Bundle ID | `com.matthias1412.exhale` |
| App Apple ID | `6798171622` |
| App name | Exhale — Quit Nicotine |
| Primary language | English (U.K.) |
| SKU | `exhale-ios` |
| Subscription group | Exhale Premium, `22287807` |
| Yearly | `exhale.yearly`, Apple ID `6798172049`, 1 year |
| Monthly | `exhale.monthly`, Apple ID `6798173484`, 1 month |

The bundle ID follows the account's existing `com.matthias1412.*` convention —
the other apps use it, and it cannot be changed once an app record is bound.

Paid Apps Agreement is **active**, with bank account and both US tax forms in
place, so subscriptions are legally sellable. Nothing financial was touched.

## Still to do in App Store Connect

- [ ] Subscription prices (€29.99/yr, €4.99/mo as the base) and availability
- [ ] 7-day free trial as an introductory offer on the yearly
- [ ] Subscription localisations — display name and description, one per plan
- [ ] A review screenshot per subscription (Apple requires one each)
- [ ] App Information: category (Health & Fitness), age rating
- [ ] Privacy policy and support URLs — **two separate public pages needed**
- [ ] App Privacy label
- [ ] Listing copy, screenshots, review notes

Apple's own banner confirms the constraint from the brief: *"Your first
auto-renewable subscription must be submitted with a new app version."* So the
subscriptions and the 1.0 build go to review together, not separately.

## What only you can do

**The App Store Connect API key.** I can create the key record, but the `.p8`
downloads exactly once and it is a private key — I don't handle those. Download
it yourself from
<https://appstoreconnect.apple.com/access/integrations/api> (Access: App
Manager), then:

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
echo -n "PICK_A_LONG_PASSPHRASE" | gh secret set MATCH_PASSWORD
```

```bash
gh secret set MATCH_GIT_BASIC_AUTHORIZATION --body "$(printf 'matthias1412:%s' "$(gh auth token)" | base64)"
```

**RevenueCat.** Add an app for `com.matthias1412.exhale`, attach the two
products above to an entitlement named exactly `premium`, then hand me the
public SDK key (`appl_…`) — public keys are safe in a binary, but it still goes
in as a secret rather than a commit.

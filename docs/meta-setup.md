# Meta setup — Instagram + Facebook Page (Aotearoa, Again)

This app posts via **Instagram API with Facebook Login** and the **Facebook Page photos API** (`graph.facebook.com/v21.0`).  
It does **not** use Instagram Login (`graph.instagram.com`).

Meta credentials are **optional**. Instagram and Facebook are gated independently:

| Channel | Required credentials | Extra gate |
|---|---|---|
| Instagram | `page_access_token` + `instagram_user_id` | DigitalNZ **Use commercially** |
| Facebook Page | `page_access_token` + `page_id` | DigitalNZ **Use commercially** |

When a channel is not configured (or the item is not commercial-use), Approver skips that delivery and Orchestrator skips publishing for it (web + email still publish).

Credentials shape:

```yaml
meta:
  page_access_token: "EAA..."     # Page access token from /me/accounts
  page_id: "1234567890"           # Facebook Page id (enables Facebook)
  instagram_user_id: "1784140..." # Instagram professional account id (enables Instagram)
app:
  host: your.public.hostname      # no https:// — must be reachable by Meta
```

Meta fetches `https://YOUR_HOST/editions/YYYY-MM-DD/share.jpg` at publish time. **localhost will not work** unless you expose the app with a public HTTPS tunnel and set `app.host` to that hostname.

Both channels post the same branded share image. Captions include attribution, the AI colourisation notice, and the public edition URL.

---

## 1. Instagram → Professional + Facebook Page

1. Instagram app → Profile → switch to **Professional** (Creator or Business).
2. Link a **Facebook Page** you admin (Accounts Centre / Sharing / Page Instagram connection).
3. Confirm in Page settings that Instagram shows as connected.

---

## 2. Create Meta developer app

1. [developers.facebook.com](https://developers.facebook.com/) → **My Apps** → **Create App**.
2. Add products:
   - **Facebook Login** (or Facebook Login for Business)
   - **Instagram** (Graph API / Facebook Login path)
3. **App settings → Basic**: copy **App ID** and **App Secret**.
4. Stay in **Development** mode. Under **Roles**, add yourself as Admin/Developer/Tester.
5. App Review is **not** required for posting only to accounts/Pages that have a role on this app.

---

## 3. Permissions

When generating a token, include at least:

- `instagram_basic`
- `instagram_content_publish`
- `pages_show_list`
- `pages_read_engagement`
- `pages_manage_posts` — required for Facebook Page photo posts

---

## 4. Short-lived User token

1. Open [Graph API Explorer](https://developers.facebook.com/tools/explorer/).
2. Select your app → **User Token**.
3. Add the permissions above → **Generate Access Token**.
4. Approve the dialog for the Page linked to Instagram.
5. Copy the token (`SHORT_LIVED_TOKEN`, ~1 hour).

---

## 5. Long-lived User token (~60 days)

```bash
curl -sS "https://graph.facebook.com/v21.0/oauth/access_token" \
  -d "grant_type=fb_exchange_token" \
  -d "client_id=YOUR_APP_ID" \
  -d "client_secret=YOUR_APP_SECRET" \
  -d "fb_exchange_token=SHORT_LIVED_TOKEN"
```

Save `access_token` as `LONG_LIVED_USER_TOKEN`.

---

## 6. Page token, Page id, Instagram user id

```bash
curl -sS "https://graph.facebook.com/v21.0/me/accounts?fields=id,name,access_token,instagram_business_account&access_token=LONG_LIVED_USER_TOKEN" | jq .
```

From your Page object:

| Field | Store as |
|---|---|
| `access_token` (Page token) | `meta.page_access_token` |
| `id` (Page id) | `meta.page_id` |
| `instagram_business_account.id` | `meta.instagram_user_id` |

Do **not** use the Page `id` as the Instagram user id.

If `instagram_business_account` is missing, the IG ↔ Page link is wrong — fix step 1. You can still post to the Facebook Page with token + `page_id` alone.

Verify Instagram:

```bash
curl -sS "https://graph.facebook.com/v21.0/USER_ID?fields=id,username&access_token=ACCESS_TOKEN" | jq .
```

Also check the token in [Access Token Debugger](https://developers.facebook.com/tools/debug/accesstoken/).

---

## 7. Rails credentials

```bash
bin/rails credentials:edit --environment development
# and/or
bin/rails credentials:edit --environment production
```

```yaml
meta:
  page_access_token: "EAA..."
  page_id: "1234567890"
  instagram_user_id: "1784140..."
app:
  host: aotearoa-again.example   # public hostname only
```

Restart server/jobs after saving.

---

## 8. Public image URL

Before publishing:

1. Edition exists with `share_image` attached (`ComposeShareImageJob`).
2. From a private/incognito window:  
   `https://YOUR_HOST/editions/YYYY-MM-DD/share.jpg` returns JPEG `200`.

---

## 9. Dry-run with curl (optional)

Instagram:

```bash
curl -sS -X POST "https://graph.facebook.com/v21.0/USER_ID/media" \
  -d "image_url=https://YOUR_HOST/editions/YYYY-MM-DD/share.jpg" \
  -d "caption=Setup test — Aotearoa, Again" \
  -d "access_token=ACCESS_TOKEN" | jq .

curl -sS -X POST "https://graph.facebook.com/v21.0/USER_ID/media_publish" \
  -d "creation_id=CONTAINER_ID" \
  -d "access_token=ACCESS_TOKEN" | jq .
```

Facebook Page:

```bash
curl -sS -X POST "https://graph.facebook.com/v21.0/PAGE_ID/photos" \
  -d "url=https://YOUR_HOST/editions/YYYY-MM-DD/share.jpg" \
  -d "caption=Setup test — Aotearoa, Again%0A%0Ahttps://YOUR_HOST/editions/YYYY-MM-DD" \
  -d "access_token=ACCESS_TOKEN" | jq .
```

---

## 10. Publish from the app

```bash
bin/rails runner '
  edition = Edition.find_by!(publish_on: Date.parse("YYYY-MM-DD"))
  Publishing::Orchestrator.new(edition).call
  puts edition.reload.state
  edition.deliveries.order(:channel).each { |d| puts "#{d.channel}: #{d.status} #{d.external_id} #{d.error_message}" }
'
```

Or wait for `PublishEditionJob` (07:00 NZ in `config/recurring.yml`).

---

## 11. Token refresh

Before the ~60-day user token expires, exchange again with the current long-lived user token as `fb_exchange_token`, then refresh the Page token from `/me/accounts` if you store that. Update credentials.

Expired tokens surface as Instagram/Facebook delivery failures → `AdminMailer.delivery_failed`.

---

## Common failures

| Symptom | Fix |
|---|---|
| Missing credentials on boot/publish | Add `meta.*` to env credentials |
| `instagram_business_account` null | Professional IG + linked Page |
| Image / media create errors | Public HTTPS `app.host` + working `/share.jpg` |
| Permission errors | Wrong scopes (need `pages_manage_posts` for Facebook), or user not a role on the Dev-mode app |
| Wrong Instagram account | Used Page id instead of `instagram_business_account.id` |
| Facebook posts fail, IG works | Missing `meta.page_id` or `pages_manage_posts` |

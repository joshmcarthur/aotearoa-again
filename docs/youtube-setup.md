# YouTube setup — Shorts (Aotearoa, Again)

This app posts **YouTube Shorts** via the [YouTube Data API v3](https://developers.google.com/youtube/v3) (`videos.insert` with resumable upload).

YouTube credentials are **optional**. When blank (or when the source item lacks DigitalNZ **Use commercially**), `EnsureEditionDeliveriesJob` marks the `youtube_short` delivery `skipped` (web + email still publish).

| Channel | Required credentials | Extra gate |
|---|---|---|
| YouTube Short | `client_id` + `client_secret` + `refresh_token` | DigitalNZ **Use commercially** |

Credentials shape:

```yaml
youtube:
  client_id: "123....apps.googleusercontent.com"
  client_secret: "GOCSPX-..."
  refresh_token: "1//0g..."   # offline OAuth token for the target channel
```

At publish time the app uploads the composed **9:16 share video** (`variant.share_video`, same MP4 as the Instagram Reel) directly from Active Storage. Unlike Meta, YouTube does **not** fetch media from a public URL — no `app.host` requirement for this channel.

The title includes `#Shorts`; the description carries attribution, the AI colourisation notice, and the public edition URL (same narrative as Instagram/Facebook).

Upload metadata defaults live on `AppConfig.youtube_upload_defaults` (not credentials): category **Education**, `containsSyntheticMedia: true`, recording date = edition `publish_on` at NZ midnight, and best-effort `locationDescription: "New Zealand"`. Comment moderation is a channel Studio setting — see §6.

If the share video is missing or YouTube rejects the upload, that delivery is marked failed and admin is emailed, but the edition still publishes (Shorts delivery is optional, like the Instagram Reel).

---

## 1. Google Cloud project + enable API

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create a project (or select an existing one).
3. **APIs & Services → Library** → search **YouTube Data API v3** → **Enable**.
4. Note the default **`videos.insert` quota**: a separate daily bucket of **100 uploads/day** (1 unit per call). Other Data API methods share a 10,000-unit pool; `search.list` has its own 100/day bucket. Quotas reset at **midnight Pacific Time**. Check usage under [APIs & Services → YouTube Data API v3 → Quotas](https://console.cloud.google.com/apis/api/youtube.googleapis.com/quotas). Request an increase in Console if you need more.

---

## 2. OAuth consent screen

1. **APIs & Services → OAuth consent screen**.
2. User type: **External** (or Internal if you use Google Workspace and only post to your org).
3. Fill app name, support email, and developer contact.
4. **Scopes → Add or remove scopes** → add:
   - `https://www.googleapis.com/auth/youtube.upload`
5. Add your Google account as a **Test user** while the app is in **Testing** mode.
6. For a personal channel you admin, Testing mode is enough — you do not need full verification if only you (and listed test users) authorize the app.

---

## 3. OAuth client credentials

1. **APIs & Services → Credentials → Create credentials → OAuth client ID**.
2. Application type: **Desktop app** (simplest for a one-time refresh-token flow) or **Web application** (if you prefer a localhost redirect).
3. For Web application, add authorized redirect URI: `http://localhost:8080/` (or your chosen redirect).
4. Copy **Client ID** and **Client secret**.

---

## 4. One-time authorization → refresh token

You need a **refresh token** with offline access. Two common approaches:

### Option A — OAuth 2.0 Playground (quickest)

1. Open [Google OAuth 2.0 Playground](https://developers.google.com/oauthplayground/).
2. Click the gear icon → check **Use your own OAuth credentials** → enter your Client ID and Client secret.
3. In Step 1, select scope `https://www.googleapis.com/auth/youtube.upload` → **Authorize APIs** → sign in as the channel owner.
4. Step 2 → **Exchange authorization code for tokens**.
5. Copy the **Refresh token** (`refresh_token` in the JSON). Store it securely — treat it like a password.

### Option B — Manual curl flow

**4a. Authorize in a browser** (replace `CLIENT_ID` and `REDIRECT_URI`):

```text
https://accounts.google.com/o/oauth2/v2/auth?client_id=CLIENT_ID&redirect_uri=REDIRECT_URI&response_type=code&scope=https://www.googleapis.com/auth/youtube.upload&access_type=offline&prompt=consent
```

Approve the dialog. Copy the `code` query parameter from the redirect URL.

**4b. Exchange code for tokens:**

```bash
curl -sS -X POST "https://oauth2.googleapis.com/token" \
  -d "code=AUTHORIZATION_CODE" \
  -d "client_id=CLIENT_ID" \
  -d "client_secret=CLIENT_SECRET" \
  -d "redirect_uri=REDIRECT_URI" \
  -d "grant_type=authorization_code" | jq .
```

Save `refresh_token` from the response. If `refresh_token` is missing, repeat step 4a with `prompt=consent` (Google only returns a refresh token on first consent or when forcing re-consent).

---

## 5. Verify channel ownership

```bash
ACCESS_TOKEN="$(curl -sS -X POST "https://oauth2.googleapis.com/token" \
  -d "grant_type=refresh_token" \
  -d "client_id=CLIENT_ID" \
  -d "client_secret=CLIENT_SECRET" \
  -d "refresh_token=REFRESH_TOKEN" | jq -r .access_token)"

curl -sS "https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq .
```

Confirm the returned channel is the one you expect. Uploads go to this channel.

---

## 6. Channel comment defaults (Studio)

Comment availability and moderation strictness are **channel defaults** in YouTube Studio. The Data API cannot set “comments on + moderation strict” per upload, so configure this once on the channel that owns the refresh token.

1. Open [YouTube Studio](https://studio.youtube.com/) while signed in as the channel owner (switch channel if you use a dedicated Shorts channel).
2. **Settings → Community moderation → Content controls** ([help article](https://support.google.com/youtube/answer/16622701)).
3. Under **Comments on new videos and posts**:
   - Turn comments **On**
   - Set comment moderation to **Strict** (holds a broader range of potentially inappropriate comments for review; alternatives are None, Basic, or Hold all)

New uploads — including API Shorts — inherit these defaults. Held comments appear under Studio’s **Comments → Held** for approve/remove.

---

## 7. Rails credentials

```bash
bin/rails credentials:edit --environment development
# and/or
bin/rails credentials:edit --environment production
```

```yaml
youtube:
  client_id: "123....apps.googleusercontent.com"
  client_secret: "GOCSPX-..."
  refresh_token: "1//0g..."
```

Restart server and `bin/jobs` after saving.

---

## 8. Share video present

Before publishing:

1. Edition exists with `share_video` attached (`ComposeShareVideoJob` runs on admin approval).
2. Requires **ffmpeg** on the host (see `README.md` / `docs/deploy.md`).

---

## 9. Dry-run upload with curl (optional)

Initiate a resumable upload:

```bash
curl -sS -D - -o /dev/null -X POST \
  "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status,recordingDetails" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json; charset=UTF-8" \
  -d '{
    "snippet": {
      "title": "Setup test — Aotearoa, Again #Shorts",
      "description": "OAuth setup test.",
      "categoryId": "27"
    },
    "status": {
      "privacyStatus": "unlisted",
      "selfDeclaredMadeForKids": false,
      "containsSyntheticMedia": true
    },
    "recordingDetails": {
      "recordingDate": "2026-08-02T00:00:00+12:00",
      "locationDescription": "New Zealand"
    }
  }'
```

Copy the `Location` header from the response, then upload the MP4:

```bash
curl -sS -X PUT "$UPLOAD_LOCATION" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: video/mp4" \
  --data-binary @share.mp4 | jq .
```

Use `privacyStatus: "unlisted"` for dry-runs; the app publishes as **public**.

---

## 10. Publish from the app

```bash
bin/rails runner '
  edition = Edition.find_by!(publish_on: Date.parse("YYYY-MM-DD"))
  edition.publish! unless edition.state == "published"
  edition.deliveries.where(status: "pending").each { |d| d.job_class.perform_now(edition.id) }
  FinalizeEditionPublishJob.perform_now(edition.id)
  puts edition.reload.state
  edition.deliveries.order(:channel).each { |d| puts "#{d.channel}: #{d.status} #{d.external_id} #{d.error_message}" }
'
```

With `bin/jobs` running, `PublishEditionJob.perform_now(edition.publish_on)` enqueues the same delivery jobs asynchronously (07:00 NZ in `config/recurring.yml`).

To test only YouTube Shorts for one edition:

```bash
bin/rails runner '
  edition = Edition.find_by!(publish_on: Date.parse("YYYY-MM-DD"))
  DeliverYoutubeShortJob.perform_now(edition.id)
  d = edition.deliveries.find_by!(channel: "youtube_short")
  puts "#{d.status} #{d.external_id} #{d.error_message}"
'
```

---

## 11. Token refresh

The app exchanges the refresh token for a short-lived access token on each upload. Refresh tokens are long-lived but can be revoked:

- User revokes access in [Google Account permissions](https://myaccount.google.com/permissions)
- OAuth client secret rotated without re-authorizing
- App removed from Testing users while still in Testing mode

Re-run section 4 to obtain a new refresh token and update credentials. Failures surface as `youtube_short` delivery failures → `AdminMailer.delivery_failed`.

---

## 12. Backfill published editions

Upload Shorts for older published editions (newest `publish_on` first). Each successful upload costs one `videos.insert` against the daily bucket — leave headroom for the next scheduled 07:00 NZ publish when it falls on the same Pacific quota day (default limit 100/day; a safe same-day backfill budget is ~97 if usage is still 0).

Preview candidates:

```bash
bin/rails runner '
  Edition.published.includes(:deliveries, :source_item, variant: { share_video_attachment: :blob })
    .order(publish_on: :desc)
    .select { |e| e.source_item.commercial_use? }
    .reject { |e| e.deliveries.find { |d| d.channel == "youtube_short" }&.then { |d| d.status == "succeeded" && d.external_id.present? } }
    .first(30)
    .each { |e| puts "#{e.publish_on} share=#{e.share_video.attached?} yt=#{e.deliveries.find { |d| d.channel == "youtube_short" }&.status || "none"}" }
'
```

Compose missing share videos and upload (set `limit` to your budget). Runs synchronously so you can stop on failure:

```bash
bin/rails runner '
  limit = 30
  abort "YouTube credentials missing" unless AppConfig.youtube_configured?

  editions = Edition.published
    .includes(:deliveries, :source_item, variant: { share_video_attachment: :blob })
    .order(publish_on: :desc)
    .select { |e| e.source_item.commercial_use? }
    .reject { |e| e.deliveries.find { |d| d.channel == "youtube_short" }&.then { |d| d.status == "succeeded" && d.external_id.present? } }
    .first(limit)

  editions.each do |edition|
    delivery = edition.deliveries.find_or_initialize_by(channel: "youtube_short")
    if delivery.new_record?
      delivery.status = delivery.applicable? ? "pending" : "skipped"
      delivery.save!
    elsif delivery.status.in?(%w[skipped failed]) && delivery.applicable?
      delivery.update!(status: "pending", error_message: nil)
    end
    next puts("SKIP #{edition.publish_on}: #{delivery.status}") if delivery.status == "skipped"

    unless edition.share_video.attached?
      puts "COMPOSE #{edition.publish_on}"
      ComposeShareVideoJob.perform_now(edition.variant_id)
      edition.variant.reload
      unless edition.share_video.attached?
        puts "FAIL #{edition.publish_on}: share_video missing"
        next
      end
    end

    puts "UPLOAD #{edition.publish_on}"
    DeliverYoutubeShortJob.perform_now(edition.id)
    delivery.reload
    puts "#{delivery.status} #{delivery.external_id} #{delivery.error_message}"
  end
'
```

Requires ffmpeg on `PATH` when composing, and decryptable `youtube.*` credentials.

---

## Common failures

| Symptom | Fix |
|---|---|
| Missing credentials on publish | Add `youtube.*` to env credentials |
| `invalid_grant` on token refresh | Refresh token revoked or expired — re-authorize (section 4) |
| `youtube_short` skipped | Credentials blank or source item lacks **Use commercially** |
| `Share video missing` | `ComposeShareVideoJob` did not run or ffmpeg unavailable |
| `uploadHttpRequest` / quota errors | `videos.insert` daily bucket exhausted (default 100/day, resets midnight PT) — wait or request increase |
| `insufficientPermissions` | Scope missing `youtube.upload` when authorizing |
| Video uploads but not a Short | Video must be vertical (9:16) and ≤ 60s — app composes ~8s 9:16 shorts; title includes `#Shorts` |
| `selfDeclaredMadeForKids` errors | API requires explicit `madeForKids` flag — app sets `selfDeclaredMadeForKids: false` |
| OAuth app blocked for non-test users | Add account as Test user, or complete OAuth verification for production |

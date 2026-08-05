# Deploying Aotearoa, Again

Home-hosted Rails app with public ingress via Cloudflare Tunnel.

## Stack on the host

- Ruby 3.4+ / Rails 8
- SQLite (files under `storage/` — primary plus Solid Cache/Queue/Cable DBs in production)
- Solid Queue (set `SOLID_QUEUE_IN_PUMA=true` or run `bin/jobs`)
- Active Storage on local disk (`storage/`) — back this directory up
- Timezone: `Pacific/Auckland`
- libvips (share stills) and **ffmpeg** (share video / shorts) — both are in the production Docker image; for bare-metal hosts install the distro packages
- `PANGOCAIRO_BACKEND=fontconfig` so branded text uses the bundled Fraunces / Source Sans fonts (see README)

## Credentials

Use **environment-specific** Rails credentials:

```bash
bin/rails credentials:edit --environment development
bin/rails credentials:edit --environment test
bin/rails credentials:edit --environment production
```

Files:

| File | Git | Notes |
|---|---|---|
| `config/credentials/development.yml.enc` | commit | Local secrets |
| `config/credentials/development.key` | ignore | Keep on your machine |
| `config/credentials/test.yml.enc` | commit | Non-sensitive test defaults |
| `config/credentials/test.key` | commit | Lets CI decrypt test credentials |
| `config/credentials/production.yml.enc` | commit | Encrypted production secrets |
| `config/credentials/production.key` | ignore | Set host `RAILS_MASTER_KEY` to this value |

| Credential | Purpose |
|---|---|
| `digitalnz.api_key` | Optional — DigitalNZ is public without a key; only needed for higher rate limits |
| `openrouter.api_key` | RubyLLM colourisation |
| `buttondown.api_key` | Email list publish |
| `buttondown.subscribe_url` | Public subscribe redirect |
| `meta.page_access_token` | Optional — Page access token; Meta deliveries skipped if blank |
| `meta.page_id` | Optional — Facebook Page id (enables Facebook Page posting) |
| `meta.instagram_user_id` | Optional — Instagram professional account id (enables Instagram) |
| `youtube.client_id` | Optional — Google OAuth client id (enables YouTube Shorts) |
| `youtube.client_secret` | Optional — Google OAuth client secret |
| `youtube.refresh_token` | Optional — offline OAuth refresh token for the target YouTube channel |
| `admin.username` / `admin.password` | HTTP Basic for `/admin` |
| `admin.alert_email` | Runway / delivery alerts |
| `app.host` | Public hostname (no protocol), e.g. `aotearoa-again.example` |
| `smtp.*` | Optional SMTP for admin alerts |

Colourise model choice lives in the DB (`models.preferred_for_colourise`). After boot:

```bash
bin/rails ruby_llm:load_models
bin/rails db:seed
```

## Process

Example with Foreman / systemd:

```bash
bin/rails db:prepare
SOLID_QUEUE_IN_PUMA=true bin/rails server -b 127.0.0.1 -p 3000
```

Or run the queue separately: `bin/jobs`.

Recurring schedules are in `config/recurring.yml` (harvest 01:00, ensure edition deliveries 06:00, publish 07:00, runway alert 08:00 Auckland).

## Cloudflare Tunnel

1. Install `cloudflared` on the host.
2. Create a tunnel pointing `https://your-domain` → `http://127.0.0.1:3000`.
3. Optional: Cloudflare Access policy on path `/admin*`.
4. Set credentials `app.host` to the public hostname (no protocol).

## Takedown

If DigitalNZ/ATL request removal:

1. In console: find the `SourceItem`, `discard!`, unpublish related `Edition` (`state` → `failed` or destroy), purge attachments if required.
2. Published permalinks should 404 once the edition is no longer `published`.

## Instagram / Facebook

Harvest is limited to NatLib's Meta-upload-eligible ATL subset (DigitalNZ **Use commercially** + **Modify**). See [natlib-social-media.md](natlib-social-media.md) for caption, people/tikanga, and takedown rules.

Optional Instagram and Facebook Page deliveries via the Meta Graph API. Credentials are optional — when a channel’s credentials are blank, or when the source item lacks DigitalNZ **Use commercially** (`SourceItem#commercial_use?`), `EnsureEditionDeliveriesJob` marks that delivery `skipped` (web + email still publish).

### Meta app setup (own account)

Step-by-step: **[meta-setup.md](meta-setup.md)**.

Summary: Professional IG + linked Facebook Page → Meta app (Facebook Login path) → long-lived Page token → store `meta.page_access_token` plus `meta.instagram_user_id` and/or `meta.page_id`. App Review not required for your own account/Page. Tokens last ~60 days; refresh before expiry. Failed Meta deliveries alert via `AdminMailer.delivery_failed`.

`PublishEditionJob` publishes the edition, then enqueues per-channel delivery jobs (`DeliverWebJob`, `DeliverEmailJob`, `DeliverInstagramJob`, `DeliverInstagramReelJob`, `DeliverFacebookJob`, `DeliverYoutubeShortJob`). Meta jobs post the branded `share_image` to Instagram (two-step container flow) and/or the Facebook Page (`/{page-id}/photos`). When all deliveries reach a terminal state, `FinalizeEditionPublishJob` emails the admin if any channel failed. Captions include the public edition URL. Email, Instagram, Facebook, Atom enclosures, and `og:image` all use `/editions/:publish_on/share.jpg` (Meta and mail clients cannot use expired signed blob URLs).

## YouTube Shorts

Optional YouTube Shorts delivery via the YouTube Data API v3. Credentials are optional — when `youtube.*` is blank, or when the source item lacks DigitalNZ **Use commercially** (`SourceItem#commercial_use?`), `EnsureEditionDeliveriesJob` marks that delivery `skipped` (web + email still publish).

### YouTube setup (own channel)

Step-by-step: **[youtube-setup.md](youtube-setup.md)**.

Summary: Google Cloud project → enable YouTube Data API v3 → OAuth consent + `youtube.upload` scope → one-time refresh token → store `youtube.client_id`, `youtube.client_secret`, and `youtube.refresh_token`. The app uploads the composed 9:16 `share.mp4` (same asset as the Instagram Reel). Failed YouTube deliveries alert via `AdminMailer.delivery_failed`.

## Container releases

Merges to `main` with [Conventional Commits](https://www.conventionalcommits.org/) messages (`feat:`, `fix:`, etc.) are picked up by [release-please](https://github.com/googleapis/release-please). It opens a release PR that bumps the version and changelog; merging that PR creates a GitHub release and tag (for example `v0.2.0`).

Publishing a GitHub release triggers the **Publish Docker image** workflow, which builds the production `Dockerfile` and pushes to GitHub Container Registry:

```text
ghcr.io/joshmcarthur/aotearoa-again:<version>
ghcr.io/joshmcarthur/aotearoa-again:latest
```

To run a tagged image on the host:

```bash
echo <github-token-with-read:packages> | docker login ghcr.io -u USERNAME --password-stdin
docker pull ghcr.io/joshmcarthur/aotearoa-again:<version>
docker run -d \
  --name aotearoa-again \
  -p 127.0.0.1:3000:80 \
  -e RAILS_MASTER_KEY=<production.key> \
  -e RAILS_ENV=production \
  -v aotearoa_again_storage:/rails/storage \
  ghcr.io/joshmcarthur/aotearoa-again:<version>
```

The image starts **Foreman** with two processes: Thruster (web) and `bin/jobs` (Solid Queue workers plus recurring schedules from `config/recurring.yml`). You do not need `SOLID_QUEUE_IN_PUMA` in the container.

The image repository is private by default. In GitHub, open **Packages → aotearoa-again → Package settings** and grant your account or org access before pulling on the host.

To publish manually without a release, run the **Publish Docker image** workflow from the Actions tab and supply a tag.

# Deploying Aotearoa, Again

Home-hosted Rails app with public ingress via Cloudflare Tunnel.

## Stack on the host

- Ruby 3.4+ / Rails 8
- SQLite (files under `storage/` — primary plus Solid Cache/Queue/Cable DBs in production)
- Solid Queue (set `SOLID_QUEUE_IN_PUMA=true` or run `bin/jobs`)
- Active Storage on local disk (`storage/`) — back this directory up
- Timezone: `Pacific/Auckland`

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
| `instagram.access_token` | Optional — long-lived Meta Graph token; Instagram delivery skipped if blank |
| `instagram.user_id` | Optional — Instagram professional account ID (with token) |
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

Recurring schedules are in `config/recurring.yml` (harvest 01:00, publish 07:00, runway alert 08:00 Auckland).

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

Optional Instagram delivery via the Meta Graph API Content Publishing flow. Credentials are optional — when blank, Approver skips creating an Instagram delivery and Orchestrator skips the channel (web + email still publish).

### Meta app setup (own account)

Step-by-step: **[instagram-meta-setup.md](instagram-meta-setup.md)**.

Summary: Professional IG + linked Facebook Page → Meta app (Facebook Login path) → long-lived token → store `instagram.access_token` + `instagram.user_id`. App Review not required for your own account. Tokens last ~60 days; refresh before expiry. Failed Instagram deliveries alert via `AdminMailer.delivery_failed`.

`PublishEditionJob` posts the branded `share_image` via the Graph API two-step container flow. Email, Instagram, Atom enclosures, and `og:image` all use `/editions/:publish_on/share.jpg` (Meta and mail clients cannot use expired signed blob URLs). **Does not cross-post to the Facebook Page feed.**

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

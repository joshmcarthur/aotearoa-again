# Bluesky + Standard.site setup

Optional Bluesky delivery posts each edition with a Standard.site-enhanced link card. Credentials are optional — when `bluesky.*` is incomplete, `EnsureEditionDeliveriesJob` marks that delivery `skipped` (web + email still run).

NatLib rules match Meta: Bluesky delivery requires DigitalNZ **Use commercially** (`SourceItem#commercial_use?`) because the share image is uploaded as an AT Protocol blob.

## Prerequisites

1. **Custom-domain Bluesky handle** matching `app.host` (Standard.site verification links your domain to AT Protocol records).
2. **App password** from Bluesky Settings → Privacy and security → App passwords.

## One-off publication bootstrap

Create the `site.standard.publication` record once per environment:

```bash
bin/rails credentials:edit --environment production
# add bluesky.handle and bluesky.app_password first

bin/rails bluesky:bootstrap_publication
```

Paste the printed values into credentials:

```yaml
bluesky:
  handle: aotearoa-again.example
  app_password: xxxx-xxxx-xxxx-xxxx
  pds_host: bsky.social              # optional; default bsky.social
  publication_uri: at://did:plc:.../site.standard.publication/...
  publication_cid: bafyrei...
app:
  bluesky_url: https://bsky.app/profile/aotearoa-again.example
```

The app serves `GET /.well-known/site.standard.publication` with the publication AT-URI for domain verification.

## Per-edition delivery

On publish day, `DeliverBlueskyJob`:

1. Creates a `site.standard.document` record (refs stored in `deliveries.metadata` on the `bluesky` row)
2. Posts an `app.bsky.feed.post` with an external embed, thumbnail, and `associatedRefs` to the document + publication records
3. Edition pages render `<link rel="site.standard.document">` tags once the delivery has written document metadata

## Verify enhanced cards

1. Open https://main.bsky.dev
2. Paste a published edition URL into the composer
3. Confirm the preview shows publication branding (name/icon), not just a bare domain link

## Manual delivery for one edition

```bash
bin/rails runner '
  edition = Edition.find_by!(publish_on: Date.parse("YYYY-MM-DD"))
  edition.publish! unless edition.state == "published"
  edition.deliveries.where(channel: "bluesky", status: "pending").each { |d| d.job_class.perform_now(edition.id) }
  d = edition.deliveries.find_by(channel: "bluesky")
  puts "#{d.status} #{d.external_id} #{d.metadata}"
'
```

## Token / record notes

- App passwords do not expire like Meta Page tokens; rotate by revoking and updating credentials.
- Re-run `bluesky:bootstrap_publication` only when migrating to a new DID or domain.
- Each edition gets its own `site.standard.document` record; the publication record is shared.

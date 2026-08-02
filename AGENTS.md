# AGENTS.md

## Cursor Cloud specific instructions

Rails 8 app ("Aotearoa, Again"): harvests ATL images via DigitalNZ, AI-colourises them (RubyLLM/OpenRouter), human-reviews in an admin UI, and publishes daily editions to the web/Atom feed/Buttondown/Instagram/Facebook/YouTube Shorts. SQLite + the Solid stack (Queue/Cache/Cable) — no external DB/Redis needed.

### Environment (already provisioned in the VM snapshot)
- Ruby 3.4.9 is installed via `rbenv` under `~/.rbenv` (interactive shells get it from `~/.bashrc`). Non-interactive commands can call binaries through the shims, e.g. `~/.rbenv/shims/bundle`, or run `eval "$(rbenv init - bash)"` first.
- System packages `libvips`, `libsqlite3-dev`, and gem build tools are installed. `libvips` is required — image rendering, the before/after slider, and `ComposeShareImageJob::Composer` all depend on `ruby-vips`.
- The update script runs `bundle install` on startup. Nothing else is automated.

### First-run steps (not in the update script)
- Create/migrate the dev DB: `bin/rails db:prepare` (idempotent; seeds preferred colourise `Model` rows on first create). `bin/rails db:seed` sets preferred models.
- `ruby_llm:load_models` and colourisation call OpenRouter and need `openrouter.api_key`; skip unless you have credentials.

### Credentials gotcha
- Only `config/credentials/test.key` is committed (tests decrypt automatically). `development.key`/`production.key` are NOT present.
- The app still boots in development without the dev key: `AppConfig.dig` rescues decryption errors, so host defaults to `localhost:3000`. Without a decryptable `admin.password`, `/admin` fails closed (`KeyError`). Credential-backed features (OpenRouter colourise, Buttondown/Meta/YouTube publish) won't work without real keys, but browsing and scheduling do.

### Run / lint / test (see `README.md`, `Procfile.dev`, `config/ci.rb`)
- Dev server: `bin/dev` (foreman: Puma on :3000 + `tailwindcss:watch`). Admin is at `/admin` (HTTP Basic from credentials: `admin.username` / `admin.password`).
- Background pipeline worker: `bin/jobs` (Solid Queue). NOT started by `Procfile.dev`; jobs use the `:solid_queue` adapter in dev, so enqueued jobs only run when `bin/jobs` is running.
- Lint: `bin/rubocop`. Tests: `bin/rails db:test:prepare test`. System tests: `bin/rails test:system`. Full local CI pipeline: `bin/ci`.

### Non-obvious caveats
- SQLite + running server: `bin/rails db:reset` deletes and recreates `storage/development.sqlite3`, but a running Puma process keeps the old file handle and will read a stale/empty DB. Restart `bin/dev` after `db:reset` (or any drop/recreate) so the server reopens the new file.
- There is no seed data for a browsable public homepage; `editions#today` renders an "empty" page until a `published` `Edition` exists for `Time.zone.today`. Seed a demo edition (a `SourceItem` → `Candidate` → chosen `Variant` with an attached `colourised_image` → `Edition`) to exercise the UI without hitting external APIs. `test/test_helper.rb` (`create_source_item`, `attach_fixture_image`) shows the object graph; `test/fixtures/files/mono_plate.jpg` is a tiny placeholder image.

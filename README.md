# Aotearoa, Again

Daily photographs from the Alexander Turnbull Library, seen again in colour.

A small Rails app that harvests reusable ATL images via DigitalNZ (Modify + Use commercially — NatLib Meta-upload-eligible subset), AI-colourises them with RubyLLM (OpenRouter), human-reviews into a ~30-day runway, and publishes to the web, Atom feed, Buttondown, and Instagram.

## Setup

```bash
bin/setup
bin/rails credentials:edit --environment development
# fill openrouter / buttondown / instagram / admin / app (digitalnz key optional)
bin/rails ruby_llm:load_models
bin/rails db:seed
bin/dev
```

Environment-specific credentials live in `config/credentials/<env>.yml.enc`.
Edit with `bin/rails credentials:edit --environment <env>`.

- Public site: http://localhost:3000  
- Admin: http://localhost:3000/admin (HTTP Basic from credentials)  
- Feed: http://localhost:3000/feed.xml  

See `config/initializers/app_config.rb` for the credentials shape.

On macOS, `bin/jobs` exports `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` **before** starting Ruby and defaults Solid Queue to `--mode async` (no `fork()`). Fork mode crashes after libvips/CoreText loads for branded share images. Override with `SOLID_QUEUE_SUPERVISOR_MODE=fork` if you need fork mode.

Share image composition also needs `PANGOCAIRO_BACKEND=fontconfig` (exported by `bin/dev` / `bin/jobs`) so libvips honours the bundled Fraunces font file instead of falling back to Helvetica on macOS.

## Pipeline

1. `HarvestCandidatesJob` — DigitalNZ ATL images with Modify + Use commercially  
2. `ColouriseCandidateJob` — RubyLLM.paint via preferred `Model` rows  
3. Admin approve → schedule `Edition`  
4. `PublishEditionJob` (07:00 NZ) — web + Buttondown + Instagram  

See [docs/deploy.md](docs/deploy.md) for home hosting + Cloudflare Tunnel.  
See [docs/natlib-social-media.md](docs/natlib-social-media.md) for NatLib social media rules.  
See [docs/instagram-meta-setup.md](docs/instagram-meta-setup.md) for Instagram Graph API setup.

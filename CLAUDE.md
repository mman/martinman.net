# martinman.net

Hugo blog (PaperMod theme as git submodule in `themes/PaperMod`), deployed to GitHub Pages
from `.github/workflows/hugo.yaml` on push to `main`. Custom domain `martinman.net`, DNS at
DigitalOcean managed by `scripts/dns-setup.sh` (doctl, idempotent, add-only).

- Config: `hugo.yaml` (YAML everywhere, no TOML). Hugo version pinned in the workflow; keep
  it equal to the local `hugo version`.
- Content: `content/posts/*.md` or page bundles `content/posts/<slug>/index.md`. New post:
  `hugo new posts/<slug>.md` (archetype in `archetypes/posts.md`). Taxonomies: tags, categories,
  series. Articles are in English.
- Build check: `hugo --gc --minify` must produce no warnings. Local preview: `hugo server -D`.
- Do not add custom layouts unless asked; the goal is a stock theme with minimal overrides.
- `static/CNAME` must stay `martinman.net` or Pages drops the custom domain on deploy.

# martinman.net

Source for [martinman.net](https://martinman.net): notes on HomeKit, Victron Energy,
Node-RED and modifying a Niesmann+Bischoff iSmove 6.9E motorhome.

Built with [Hugo](https://gohugo.io/) and the
[PaperMod](https://github.com/adityatelange/hugo-PaperMod) theme, deployed to GitHub Pages
by GitHub Actions on every push to `main`.

## Local development

```sh
brew install hugo                      # Hugo extended, once
git clone --recurse-submodules git@github.com:mman/martinman.net.git
cd martinman.net
hugo server -D                         # http://localhost:1313, includes drafts
```

If you cloned without `--recurse-submodules`:

```sh
git submodule update --init --recursive
```

## Writing a post

```sh
hugo new posts/my-post-slug.md
```

This uses `archetypes/posts.md`. Edit the front matter:

```yaml
title: "Adding a second alternator to the iSmove"
date: 2026-11-09T15:30:00+01:00
draft: true          # set to false to publish
description: "One-line summary shown in lists and search"
tags: [victron, electrics]
series: ["iSmove power upgrade"]   # groups multi-part articles under /series/
showToc: true
```

Images go next to the post as a
[page bundle](https://gohugo.io/content-management/page-bundles/):

```
content/posts/my-post-slug/
├── index.md
└── wiring.jpg        -> ![Wiring](wiring.jpg)
```

Posts with `draft: true` are visible locally with `hugo server -D` but are not built in CI.

## Deployment

`.github/workflows/hugo.yaml` builds the site with the pinned Hugo version and publishes
`public/` to GitHub Pages. Nothing else to do: push to `main`.

Repository settings that must be in place (already done via `gh api`):

- Settings → Pages → Source: **GitHub Actions**
- Settings → Pages → Custom domain: `martinman.net` (also kept in `static/CNAME`)
- Settings → Pages → **Enforce HTTPS** (enable once the certificate is issued)

## DNS (DigitalOcean)

`scripts/dns-setup.sh` creates the records GitHub Pages needs using `doctl`. It is idempotent
and never deletes anything, so mail records stay intact.

```sh
scripts/dns-setup.sh --dry-run   # show what would be created
scripts/dns-setup.sh             # create missing records
```

Records it manages:

| Type  | Host | Value                                        |
|-------|------|----------------------------------------------|
| A     | @    | 185.199.108.153 … 185.199.111.153 (4 records) |
| AAAA  | @    | 2606:50c0:8000::153 … 2606:50c0:8003::153 (4) |
| CNAME | www  | mman.github.io.                              |

After propagation, enforce HTTPS (retry later if GitHub has not issued the certificate yet):

```sh
gh api -X PUT repos/mman/martinman.net/pages -F https_enforced=true
```

## Updating the theme

```sh
git submodule update --remote --merge themes/PaperMod
git commit -am "Update PaperMod"
```

Swapping to a different theme from <https://themes.gohugo.io/>: replace the submodule,
change `theme:` in `hugo.yaml`, and adjust `params`.

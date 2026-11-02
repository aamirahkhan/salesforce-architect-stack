# Distribution

Where the Salesforce Architect Stack gets published, what can be automated, and what has to be
done by hand. The distinction is not preference — three of the four channels have no public
write API.

## Channel matrix

| Channel | Programmatic publishing | What actually works |
| --- | --- | --- |
| **Canonical site (GitHub Pages)** | Yes | Jekyll builds `docs/` on every push to `main`. (https://aamirahkhan.github.io/salesforce-architect-stack/) |
| **Dev.to** | Yes | Official Forem API, self-serve API key. `distribution/publish-devto.mjs` handles it. |
| **LinkedIn Articles** | No | Articles must be composed in the LinkedIn UI. The Posts API can share a link to the article with its own title/description/thumbnail, but the API's "article" content type is a link preview, not a long-form Article. |
| **Medium** | No (for new integrations) | Medium stopped issuing new integration tokens and states the API is no longer supported. Use Medium's import-by-RSS/manual paste instead. |
| **Trailblazer Community** | No | Post manually in the Trailblazer feed or a group. No documented write API. |
| **Salesforce Developer Blog / Architecture Blog** | No | Editorial submission only. The Architecture Blog runs a Community Author Program with application windows; editors publish. |

Sources: [Dev.to API](https://developers.forem.com/api/v0), [Medium API docs](https://github.com/Medium/medium-api-docs),
[Salesforce Architecture Blog author program](https://www.salesforce.com/blog/salesforce-architecture-blog-community-author-program/).

## Recommended sequence

Publish the canonical article first, then cross-post with a canonical URL so search engines credit
the original:

1. **Canonical** — [aamirahkhan.github.io/salesforce-architect-stack](https://aamirahkhan.github.io/salesforce-architect-stack/articles/rebuilding-the-trigger-framework/).
   Automated: push to `main`.
2. **Dev.to** — publish with `canonical_url` pointing at the original. Automated.
3. **LinkedIn Article** — paste the article, link back to the canonical URL. Manual.
4. **Medium** — import or paste, linking back. Manual.
5. **Trailblazer Community** — post a shorter discussion version in a relevant group, inviting
   architects to review the repository. Manual.

## The canonical site

The article site lives in `docs/` and is built by GitHub Pages with Jekyll in safe mode:

```
docs/_config.yml                     site URL, baseurl, author, markdown settings
docs/_layouts/default.html           head metadata, OG/Twitter tags, JSON-LD, header and footer
docs/_layouts/article.html           article shell: title, lede, byline, tags
docs/assets/site.css                 the only stylesheet
docs/articles/*.md                   one file per article, `layout: article`
docs/assets/gifs/                    images referenced by the articles
```

Rules that keep the built site correct:

- **Root-relative paths include the baseurl.** The site is served from `/salesforce-architect-stack/`,
  so an image is `/salesforce-architect-stack/assets/gifs/trigger-flow-v2.gif` and a link is
  `/salesforce-architect-stack/articles/...`. Dev.to ignores paths that start with `//`.
- **Every article sets `permalink`, `date` and `description`.** The layout derives the canonical URL,
  the JSON-LD and the reading time from them; a missing `date` silently breaks both.
- **Tags are a YAML list**, `tags: [salesforce, apex]`. The Dev.to publisher accepts either form.
- **Only article pages are published.** `exclude` in `_config.yml` keeps the repository docs and ADRs
  out of the site.

Publishing a new article:

1. Add `docs/articles/<slug>.md` with front matter (`layout`, `title`, `description`, `tags`,
   `date`, `permalink`, `image`).
2. Copy its images into `docs/assets/gifs/` with a versioned filename so caches and social previews
   pick up replacements.
3. Add it to `docs/index.html` and `docs/sitemap.xml`.
4. Push to `main` and wait for the Pages build, then open the permalink and confirm the `<link
   rel="canonical">`, `og:image` and the article render.

## Connecting Dev.to

1. Create a key at **dev.to → Settings → Extensions → DEV Community API Keys**.
2. Save it to `.devto-key` in the repository root (gitignored), or export `DEVTO_API_KEY`.
   Never commit the key or paste it into a chat.
3. Preview the payload without publishing:

   ```bash
   node distribution/publish-devto.mjs --file article.md --dry-run
   ```

4. Create a draft, review it on Dev.to, then publish:

   ```bash
   node distribution/publish-devto.mjs --file article.md --draft
   ```

   Or publish directly with `--title`, `--tags salesforce,architecture`, and `--canonical`.

To update an article that already exists instead of creating a duplicate, pass its id:

```bash
node distribution/publish-devto.mjs --file docs/articles/rebuilding-the-trigger-framework.md \
  --id <articleId> --canonical https://aamirahkhan.github.io/salesforce-architect-stack/articles/rebuilding-the-trigger-framework/
```

The publisher makes root-relative image paths absolute against the canonical origin, because Dev.to
would otherwise resolve `/salesforce-architect-stack/assets/...` against dev.to itself. Explicit
flags win over front matter; front matter wins over built-in defaults.

```markdown
---
title: Rebuilding the Salesforce trigger framework as a baseline
description: A layered Apex baseline with metadata-driven triggers and user-mode access.
tags: salesforce, architecture, apex
canonical_url: https://example.com/articles/apex-baseline
series: Salesforce Architect Stack
---

Article body…
```

## Manual channel checklist

**LinkedIn Article**

- [ ] Lead with the architectural problem, not the feature list
- [ ] One diagram (the layer flow), no screenshots of code
- [ ] Link to the repository in the first three paragraphs
- [ ] End with a specific question to invite architect feedback

**Medium**

- [ ] Import from the canonical URL where possible
- [ ] Keep the same title and headings for consistency
- [ ] Set the canonical link if Medium's import offers it

**Trailblazer Community**

- [ ] Post in a group where architects are active, not the general feed
- [ ] Ask for review of a specific decision (trigger bypass, user-mode access), not generic feedback
- [ ] Never post the same text as the Dev.to/LinkedIn article; the community rewards discussion

**Salesforce Developer Blog / Architecture Blog**

- [ ] Pitch a specific architectural argument, not a tutorial
- [ ] Apply during the next Community Author Program window
- [ ] Expect editorial latency; do not block the launch on it

## What is not stored here

No credentials, tokens or session cookies belong in this directory. `.devto-key` is gitignored.
Any future OAuth integration should store tokens outside the repository.

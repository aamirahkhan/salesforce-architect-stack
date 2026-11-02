#!/usr/bin/env node
/**
 * Publish a Markdown article to Dev.to through the official Forem API.
 *
 * Why this is a script and not a platform integration: Dev.to is the only target channel
 * with a self-serve write API. LinkedIn Articles and the Salesforce community properties
 * are UI/editorial only, and Medium stopped issuing integration tokens. Keeping the
 * publisher small and local avoids pretending those channels can be automated.
 *
 * The canonical article lives on GitHub Pages. Article bodies use root-relative image
 * paths so the same Markdown renders there; this script makes those URLs absolute before
 * sending them to Dev.to, where a root-relative path would resolve against dev.to.
 *
 * Auth: DEVTO_API_KEY, or a .devto-key file at the repository root. The key is read once,
 * sent only to api.dev.to, and never printed — not even in --dry-run output.
 */
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const API_URL = 'https://dev.to/api/articles';
const KEY_FILE = path.resolve(process.cwd(), '.devto-key');
const USER_AGENT = 'salesforce-architect-stack-publisher/1.0';
const MAX_TAGS = 4;

function printUsage() {
    console.log(`Publish a Markdown article to Dev.to.

Usage:
  node distribution/publish-devto.mjs --file article.md [options]

Options:
  --file <path>         Markdown file to publish (required unless --help)
  --id <articleId>      Update an existing Dev.to article instead of creating one
  --title <text>        Override the title (otherwise front matter "title")
  --tags <a,b>          Override tags (otherwise front matter "tags")
  --canonical <url>     Canonical URL of the original article
  --description <text>  SEO description (otherwise front matter "description")
  --cover <url>         Cover image URL (otherwise front matter "cover_image")
  --series <name>       Dev.to series name
  --draft               Create or update as a draft instead of publishing
  --dry-run             Print the request payload without calling the API
  --help                Show this help

Front matter (optional) is a simple key: value block between --- lines:
  ---
  title: Your title
  description: One-sentence summary
  tags: salesforce, architecture
  canonical_url: https://example.com/article
  cover_image: https://example.com/cover.png
  series: Building an Apex baseline
  ---

Environment:
  DEVTO_API_KEY   Dev.to API key (Settings -> Extensions -> DEV Community API Keys).
                  Alternatively save it to .devto-key in the repository root.
                  Never commit that file.
`);
}

function parseArgs(argv) {
    const args = { tags: [], draft: false, dryRun: false, help: false };
    for (let index = 0; index < argv.length; index += 1) {
        const flag = argv[index];
        const next = () => {
            const value = argv[index + 1];
            if (!value || value.startsWith('--')) {
                throw new Error(`Missing value for ${flag}`);
            }
            index += 1;
            return value;
        };

        switch (flag) {
            case '--file':
                args.file = next();
                break;
            case '--id': {
                const value = next();
                if (!/^\d+$/.test(value)) {
                    throw new Error('--id must be a numeric Dev.to article id');
                }
                args.id = value;
                break;
            }
            case '--title':
                args.title = next();
                break;
            case '--tags':
                args.tags = next().split(',').map((tag) => tag.trim()).filter(Boolean);
                break;
            case '--canonical':
                args.canonical = next();
                break;
            case '--description':
                args.description = next();
                break;
            case '--cover':
                args.cover = next();
                break;
            case '--series':
                args.series = next();
                break;
            case '--draft':
                args.draft = true;
                break;
            case '--dry-run':
                args.dryRun = true;
                break;
            case '--help':
            case '-h':
                args.help = true;
                break;
            default:
                throw new Error(`Unknown option: ${flag}`);
        }
    }
    return args;
}

/** Splits an optional simple YAML front matter block from the Markdown body. */
function splitFrontMatter(markdown) {
    const normalized = markdown.replace(/\r\n/g, '\n');
    if (!normalized.startsWith('---\n')) {
        return { data: {}, body: normalized.trim() };
    }

    const end = normalized.indexOf('\n---', 4);
    if (end === -1) {
        return { data: {}, body: normalized.trim() };
    }

    const data = {};
    for (const line of normalized.slice(4, end).split('\n')) {
        const separator = line.indexOf(':');
        if (separator === -1) {
            continue;
        }
        const key = line.slice(0, separator).trim();
        const rawValue = line.slice(separator + 1).trim();
        if (!key) {
            continue;
        }
        if (rawValue.startsWith('[') && rawValue.endsWith(']')) {
            data[key] = rawValue
                .slice(1, -1)
                .split(',')
                .map((item) => item.trim().replace(/^["']|["']$/g, ''))
                .filter(Boolean);
            continue;
        }
        data[key] = rawValue.replace(/^["']|["']$/g, '');
    }

    return { data, body: normalized.slice(end + 4).trim() };
}

/**
 * Makes site-root paths absolute against the canonical article's origin. Dev.to would
 * otherwise resolve `/salesforce-architect-stack/assets/...` against dev.to itself.
 */
function absolutizeBodyUrls(body, canonicalUrl) {
    if (!canonicalUrl) {
        return body;
    }
    const origin = new URL(canonicalUrl).origin;
    return body
        .replace(/\]\((\/(?!\/)[^)\s]+)\)/g, (match, pathname) => `](${origin}${pathname})`)
        .replace(
            /(\bsrc=["'])(\/(?!\/)[^"']+)(["'])/g,
            (match, prefix, pathname, suffix) => `${prefix}${origin}${pathname}${suffix}`
        );
}

async function resolveApiKey() {
    if (process.env.DEVTO_API_KEY) {
        return process.env.DEVTO_API_KEY.trim();
    }
    try {
        return (await readFile(KEY_FILE, 'utf8')).trim();
    } catch {
        return null;
    }
}

async function main() {
    let args;
    try {
        args = parseArgs(process.argv.slice(2));
    } catch (error) {
        console.error(`Error: ${error.message}`);
        printUsage();
        process.exit(1);
    }

    if (args.help) {
        printUsage();
        return;
    }
    if (!args.file) {
        console.error('Error: --file is required.');
        printUsage();
        process.exit(1);
    }

    const markdown = await readFile(args.file, 'utf8');
    const { data, body: rawBody } = splitFrontMatter(markdown);

    const title = args.title || data.title;
    if (!title) {
        console.error('Error: provide a title with --title or front matter.');
        process.exit(1);
    }

    const frontMatterTags = Array.isArray(data.tags) ? data.tags : (data.tags || '').split(',');
    const tags = (args.tags.length > 0
        ? args.tags
        : frontMatterTags.map((tag) => tag.trim()).filter(Boolean)
    ).slice(0, MAX_TAGS);

    const canonicalUrl = args.canonical || data.canonical_url;
    if (canonicalUrl) {
        try {
            new URL(canonicalUrl);
        } catch {
            console.error(`Error: canonical URL is not absolute: ${canonicalUrl}`);
            process.exit(1);
        }
    }

    const article = {
        title,
        body_markdown: absolutizeBodyUrls(rawBody, canonicalUrl),
        published: !args.draft,
        tags,
        canonical_url: canonicalUrl || undefined,
        description: args.description || data.description || undefined,
        main_image: args.cover || data.cover_image || data.main_image || undefined,
        series: args.series || data.series || undefined
    };

    if (args.dryRun) {
        console.log(JSON.stringify({ article }, null, 2));
        return;
    }

    const apiKey = await resolveApiKey();
    if (!apiKey) {
        console.error(
            'Error: no Dev.to API key. Set DEVTO_API_KEY or save the key to .devto-key (gitignored).'
        );
        process.exit(1);
    }

    const endpoint = args.id ? `${API_URL}/${args.id}` : API_URL;
    const response = await fetch(endpoint, {
        method: args.id ? 'PUT' : 'POST',
        headers: {
            'Content-Type': 'application/json',
            'User-Agent': USER_AGENT,
            'api-key': apiKey
        },
        body: JSON.stringify({ article })
    });

    const text = await response.text();
    if (!response.ok) {
        console.error(`Dev.to rejected the request (${response.status}):`);
        console.error(text);
        process.exit(1);
    }

    let created;
    try {
        created = JSON.parse(text);
    } catch {
        console.error('Dev.to returned a non-JSON response:');
        console.error(text);
        process.exit(1);
    }

    const action = args.draft ? 'Draft saved' : 'Published';
    console.log(`${action}: ${created.url}`);
    console.log(`Article id: ${created.id}`);
}

main().catch((error) => {
    console.error(`Unexpected failure: ${error.message}`);
    process.exit(1);
});

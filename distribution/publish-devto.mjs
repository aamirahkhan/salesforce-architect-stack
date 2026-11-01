#!/usr/bin/env node
/**
 * Publish a Markdown article to Dev.to through the official Forem API.
 *
 * Why this is a script and not a platform integration: Dev.to is the only target channel
 * with a self-serve write API. LinkedIn Articles and the Salesforce community properties
 * are UI/editorial only, and Medium stopped issuing integration tokens. Keeping the
 * publisher small and local avoids pretending those channels can be automated.
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
  --title <text>        Override the title (otherwise front matter "title")
  --tags <a,b>          Override tags (otherwise front matter "tags")
  --canonical <url>     Canonical URL of the original article
  --description <text>  SEO description (otherwise front matter "description")
  --cover <url>         Cover image URL (otherwise front matter "cover_image")
  --series <name>       Dev.to series name
  --draft               Create as a draft instead of publishing
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
        const value = line.slice(separator + 1).trim().replace(/^["']|["']$/g, '');
        if (key) {
            data[key] = value;
        }
    }

    return { data, body: normalized.slice(end + 4).trim() };
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
    const { data, body } = splitFrontMatter(markdown);

    const title = args.title || data.title;
    if (!title) {
        console.error('Error: provide a title with --title or front matter.');
        process.exit(1);
    }

    const tags = (args.tags.length > 0
        ? args.tags
        : (data.tags || '').split(',').map((tag) => tag.trim()).filter(Boolean)
    ).slice(0, MAX_TAGS);

    const article = {
        title,
        body_markdown: body,
        published: !args.draft,
        tags,
        canonical_url: args.canonical || data.canonical_url || undefined,
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

    const response = await fetch(API_URL, {
        method: 'POST',
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

    console.log(`${args.draft ? 'Draft created' : 'Published'}: ${created.url}`);
    console.log(`Article id: ${created.id}`);
}

main().catch((error) => {
    console.error(`Unexpected failure: ${error.message}`);
    process.exit(1);
});

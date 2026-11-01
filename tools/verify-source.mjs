#!/usr/bin/env node
/**
 * Source verification for the Salesforce Architect Stack.
 *
 * Runs without an org: parses every Apex class and trigger with the ANTLR-based
 * Apex parser, validates XML and JSON well-formedness, checks that every Apex
 * class has metadata, and verifies qualified calls to framework classes resolve
 * to a declared method.
 *
 * Usage: npm run verify
 */
import { readdir, readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ApexParserFactory, ApexErrorListener } from '@apexdevtools/apex-parser';
import { XMLValidator } from 'fast-xml-parser';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SOURCE_ROOT = path.join(ROOT, 'force-app');
const SKIP_DIRS = new Set(['node_modules', '.git', '.sfdx', '.sf', 'coverage', 'test-results']);

const diagnostics = [];
const stats = { apex: 0, xml: 0, json: 0 };

async function walk(directory, files = []) {
  let entries;
  try {
    entries = await readdir(directory, { withFileTypes: true });
  } catch {
    return files;
  }
  for (const entry of entries) {
    if (SKIP_DIRS.has(entry.name)) continue;
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      await walk(absolute, files);
    } else {
      files.push(absolute);
    }
  }
  return files;
}

const relativePath = (file) => path.relative(ROOT, file);

class CollectingErrorListener extends ApexErrorListener {
  constructor(file) {
    super();
    this.file = file;
  }

  apexSyntaxError(line, column, message) {
    diagnostics.push(`${relativePath(this.file)}:${line}:${column} ${message}`);
  }
}

async function verifyApex(file) {
  const source = await readFile(file, 'utf8');
  const listener = new CollectingErrorListener(file);
  try {
    const { parser } = ApexParserFactory.createLexerAndParser(source, listener);
    if (file.endsWith('.trigger')) {
      parser.triggerUnit();
    } else {
      parser.compilationUnit();
    }
    stats.apex += 1;
  } catch (error) {
    diagnostics.push(`${relativePath(file)}: parser failure: ${error.message}`);
  }
}

function verifyXml(file, source) {
  const result = XMLValidator.validate(source, { allowBooleanAttributes: true });
  if (result !== true) {
    diagnostics.push(`${relativePath(file)}:${result.err.line}: XML ${result.err.code} ${result.err.msg}`);
    return;
  }
  stats.xml += 1;
}

function verifyJson(file, source) {
  try {
    JSON.parse(source);
    stats.json += 1;
  } catch (error) {
    diagnostics.push(`${relativePath(file)}: invalid JSON: ${error.message}`);
  }
}

function verifyMetadataPairing(files) {
  const pairedExtensions = [
    { source: '.cls', metadata: '.cls-meta.xml' },
    { source: '.trigger', metadata: '.trigger-meta.xml' }
  ];

  for (const { source, metadata } of pairedExtensions) {
    for (const file of files.filter((candidate) => candidate.endsWith(source))) {
      if (!existsSync(`${file}-meta.xml`)) {
        diagnostics.push(`${relativePath(file)}: missing metadata file ${path.basename(file)}${metadata.slice(source.length)}`);
      }
    }
    for (const file of files.filter((candidate) => candidate.endsWith(metadata))) {
      const sourceFile = file.slice(0, -'-meta.xml'.length);
      if (!existsSync(sourceFile)) {
        diagnostics.push(`${relativePath(file)}: metadata has no matching ${source} file`);
      }
    }
  }
}

const METHOD_DECLARATION =
  /^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:public|private|protected|global)\s+(?:static\s+)?(?:virtual\s+|abstract\s+|override\s+|final\s+)*[\w.<>,[\]]+\s+(\w+)\s*\(/gm;

function declaredMethods(source) {
  const names = new Set();
  for (const match of source.matchAll(METHOD_DECLARATION)) {
    names.add(match[1]);
  }
  return names;
}

async function verifyFrameworkReferences(files) {
  const classes = new Map();
  const apexFiles = files.filter((file) => file.endsWith('.cls'));

  for (const file of apexFiles) {
    const name = path.basename(file, '.cls');
    classes.set(name, declaredMethods(await readFile(file, 'utf8')));
  }

  for (const file of files.filter((candidate) => candidate.endsWith('.cls') || candidate.endsWith('.trigger'))) {
    const source = await readFile(file, 'utf8');
    for (const match of source.matchAll(/\b([A-Z][A-Za-z0-9_]+)\.(\w+)\s*\(/g)) {
      const [, className, methodName] = match;
      const methods = classes.get(className);
      if (!methods) continue;
      if (!methods.has(methodName)) {
        diagnostics.push(`${relativePath(file)}: call to ${className}.${methodName}() has no matching declaration`);
      }
    }
  }
}

async function main() {
  const files = await walk(SOURCE_ROOT);

  for (const file of files) {
    if (file.endsWith('.cls') || file.endsWith('.trigger')) {
      await verifyApex(file);
    } else if (file.endsWith('.xml')) {
      verifyXml(file, await readFile(file, 'utf8'));
    } else if (file.endsWith('.json')) {
      verifyJson(file, await readFile(file, 'utf8'));
    }
  }

  verifyMetadataPairing(files);
  await verifyFrameworkReferences(files);

  if (diagnostics.length > 0) {
    console.error(`Verification failed with ${diagnostics.length} problem(s):\n`);
    for (const diagnostic of diagnostics) {
      console.error(`  - ${diagnostic}`);
    }
    process.exit(1);
  }

  console.log(
    `Verified ${stats.apex} Apex files, ${stats.xml} XML files and ${stats.json} JSON files. No problems found.`
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

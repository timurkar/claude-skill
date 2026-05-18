#!/usr/bin/env node
/**
 * Installs the chatium-sync Claude Code skill into ~/.claude/skills/chatium-sync/
 * Downloads skill files from GitHub at install time.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');

const REPO = 'timurkar/claude-skill';
const BRANCH = process.env.CHATIUM_SKILL_BRANCH || 'main';
const SKILL_DIR = path.join(os.homedir(), '.claude', 'skills', 'chatium-sync');

const FILES = [
  { name: 'SKILL.md', executable: false },
  { name: 'chatium-sync.sh', executable: true },
  { name: 'coding.md', executable: false },
  { name: 'heap.md', executable: false },
  { name: 'heap-filter.md', executable: false },
  { name: 'auth.md', executable: false },
  { name: 'routing.md', executable: false },
  { name: 'storage.md', executable: false },
];

// ANSI colors
const c = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  blue: '\x1b[34m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  dim: '\x1b[2m',
};

function log(msg) { console.log(`${c.blue}[chatium-skill]${c.reset} ${msg}`); }
function ok(msg)  { console.log(`${c.green}[chatium-skill]${c.reset} ${msg}`); }
function warn(msg){ console.log(`${c.yellow}[chatium-skill]${c.reset} ${msg}`); }
function err(msg) { console.error(`${c.red}[chatium-skill]${c.reset} ${msg}`); }

function download(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { headers: { 'User-Agent': 'chatium-claude-skill-installer' } }, (res) => {
      // Handle redirects
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        res.resume();
        return download(res.headers.location).then(resolve, reject);
      }
      if (res.statusCode !== 200) {
        return reject(new Error(`HTTP ${res.statusCode} for ${url}`));
      }
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    });
    req.on('error', reject);
    req.setTimeout(30000, () => req.destroy(new Error(`Timeout fetching ${url}`)));
  });
}

async function main() {
  log(`Installing Chatium Sync skill to ${SKILL_DIR}`);
  log(`Downloading from github.com/${REPO}@${BRANCH}`);

  // Ensure skill dir exists
  fs.mkdirSync(SKILL_DIR, { recursive: true });

  let succeeded = 0;
  let failed = 0;

  for (const file of FILES) {
    const url = `https://raw.githubusercontent.com/${REPO}/${BRANCH}/${file.name}`;
    const target = path.join(SKILL_DIR, file.name);
    try {
      const data = await download(url);
      fs.writeFileSync(target, data);
      if (file.executable) {
        try { fs.chmodSync(target, 0o755); } catch (_) {}
      }
      ok(`  ${file.name} (${data.length} bytes)`);
      succeeded++;
    } catch (e) {
      err(`  Failed: ${file.name} — ${e.message}`);
      failed++;
    }
  }

  console.log('');
  if (failed === 0) {
    ok(`Skill installed: ${succeeded} files written to ${SKILL_DIR}`);
    console.log('');
    console.log(`${c.dim}Restart Claude Code, then use /chatium-sync to sync your project.${c.reset}`);
    console.log('');
    console.log(`${c.dim}Quick start:${c.reset}`);
    console.log(`  1. cd into your Chatium project folder`);
    console.log(`  2. /chatium-sync init <account> <token>`);
    console.log(`  3. /chatium-sync sync`);
  } else {
    err(`Install completed with errors: ${succeeded} ok, ${failed} failed`);
    process.exit(1);
  }
}

main().catch((e) => {
  err(`Install failed: ${e.message}`);
  process.exit(1);
});

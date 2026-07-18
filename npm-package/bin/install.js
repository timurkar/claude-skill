#!/usr/bin/env node
/**
 * Installs the chatium-sync skill for AI coding agents (Claude Code, Codex CLI).
 * Downloads skill files from GitHub at install time and copies them into each
 * agent's skills directory: ~/.claude/skills/chatium-sync and/or ~/.codex/skills/chatium-sync.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');

const REPO = 'timurkar/claude-skill';
const BRANCH = process.env.CHATIUM_SKILL_BRANCH || 'main';

const AGENTS = [
  { name: 'Claude Code', home: path.join(os.homedir(), '.claude'), restart: 'Restart Claude Code' },
  { name: 'Codex CLI', home: path.join(os.homedir(), '.codex'), restart: 'Restart Codex' },
];

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
    const req = https.get(url, { headers: { 'User-Agent': 'chatium-skill-installer' } }, (res) => {
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
  // Install into every agent whose home directory exists; default to Claude Code if none found.
  let targets = AGENTS.filter((a) => fs.existsSync(a.home));
  if (targets.length === 0) {
    warn('Neither ~/.claude nor ~/.codex found — installing for Claude Code by default.');
    targets = [AGENTS[0]];
  }

  log(`Downloading from github.com/${REPO}@${BRANCH}`);
  const downloaded = [];
  for (const file of FILES) {
    const url = `https://raw.githubusercontent.com/${REPO}/${BRANCH}/${file.name}`;
    const data = await download(url);
    downloaded.push({ ...file, data });
    ok(`  ${file.name} (${data.length} bytes)`);
  }

  console.log('');
  for (const agent of targets) {
    const skillDir = path.join(agent.home, 'skills', 'chatium-sync');
    fs.mkdirSync(skillDir, { recursive: true });
    for (const file of downloaded) {
      const target = path.join(skillDir, file.name);
      fs.writeFileSync(target, file.data);
      if (file.executable) {
        try { fs.chmodSync(target, 0o755); } catch (_) {}
      }
    }
    ok(`${agent.name}: skill installed to ${skillDir}`);
  }

  console.log('');
  console.log(`${c.dim}${targets.map((t) => t.restart).join(' / ')}, then the chatium-sync skill is available.${c.reset}`);
  console.log('');
  console.log(`${c.dim}Quick start:${c.reset}`);
  console.log(`  1. cd into your Chatium project folder`);
  console.log(`  2. Ask the agent to connect the folder to your Chatium account`);
  console.log(`     (in Claude Code: /chatium-sync init <account> <token>)`);
}

main().catch((e) => {
  err(`Install failed: ${e.message}`);
  process.exit(1);
});

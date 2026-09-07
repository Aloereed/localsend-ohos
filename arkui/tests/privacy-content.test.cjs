const { execFileSync } = require('node:child_process');
const path = require('node:path');
execFileSync(process.execPath, [path.join(__dirname, '../sync-privacy.cjs'), '--check'], { stdio: 'inherit' });

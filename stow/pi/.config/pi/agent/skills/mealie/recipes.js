#!/usr/bin/env node
const https = require('https');

const MEALIE_URL = 'mealie.local.birkenhügel.de';
const MEALIE_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJsb25nX3Rva2VuIjp0cnVlLCJpZCI6IjY3N2JhZWFjLTNjZDMtNDAzZS1hYmE4LTkzYTI3YThiNjBlMCIsIm5hbWUiOiJQaSIsImludGVncmF0aW9uX2lkIjoiZ2VuZXJpYyIsImV4cCI6MTkzNDkxMjU5N30.k2e4_hQ8aBbiOuG6Ka3y-OljPQtUJID7blP3X0PJZko';

function request(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: MEALIE_URL,
      port: 443,
      path,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${MEALIE_TOKEN}`,
        'Content-Type': 'application/json'
      },
      rejectUnauthorized: false
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

const cmd = process.argv[2];
const arg = process.argv[3];

(async () => {
  try {
    if (cmd === 'list') {
      const data = await request('/api/recipes?skip=0&limit=100');
      data.items.forEach(r => console.log(`- ${r.name}`));
    } else if (cmd === 'get') {
      const slug = arg.toLowerCase().replace(/\s+/g, '-');
      const data = await request(`/api/recipes/${slug}`);
      console.log(JSON.stringify(data, null, 2));
    } else if (cmd === 'search') {
      const data = await request(`/api/recipes?search=${encodeURIComponent(arg)}`);
      data.items.forEach(r => console.log(`- ${r.name}`));
    }
  } catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
  }
})();

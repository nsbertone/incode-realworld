// k6 load test for the backend API: the bonus "performance regression
// detection" step of the pipeline.
//
// Runs in CI against the freshly built backend image + PostgreSQL (same setup
// as the API spec tests). Two kinds of checks:
//   1. absolute thresholds below: the build fails if they are crossed;
//   2. compare.py compares p95 per endpoint with the last successful run on
//      main and fails on a regression larger than the allowed ratio.
//
//   k6 run -e BASE_URL=http://localhost:8000 loadtest/api.js
import http from 'k6/http';
import { check, group } from 'k6';

const BASE = __ENV.BASE_URL || 'http://localhost:8000';
const JSON_HEADERS = { 'Content-Type': 'application/json' };

export const options = {
  scenarios: {
    // Mostly reads, like a real blog: anonymous browsing plus a small share
    // of logged-in writes.
    readers: {
      executor: 'constant-vus',
      vus: Number(__ENV.VUS || 20),
      duration: __ENV.DURATION || '60s',
      exec: 'reader',
    },
    writers: {
      executor: 'constant-arrival-rate',
      rate: 2,
      timeUnit: '1s',
      duration: __ENV.DURATION || '60s',
      preAllocatedVUs: 5,
      exec: 'writer',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    'http_req_duration{endpoint:list_articles}': ['p(95)<500'],
    'http_req_duration{endpoint:get_article}': ['p(95)<300'],
    'http_req_duration{endpoint:tags}': ['p(95)<300'],
    'http_req_duration{endpoint:create_article}': ['p(95)<800'],
    checks: ['rate>0.99'],
  },
  summaryTrendStats: ['avg', 'p(50)', 'p(95)', 'p(99)', 'max'],
};

// Runs once: one user and a few articles to read.
export function setup() {
  const id = `${Date.now()}`;
  const user = { username: `k6${id}`, email: `k6${id}@example.com`, password: 'k6-load-test-pw' };
  const res = http.post(`${BASE}/api/users`, JSON.stringify({ user }), { headers: JSON_HEADERS });
  check(res, { 'register 201': (r) => r.status === 201 });
  const token = res.json('user.token');
  const auth = { ...JSON_HEADERS, Authorization: `Token ${token}` };

  const slugs = [];
  for (let i = 0; i < 20; i++) {
    const article = {
      title: `k6 article ${id} ${i}`,
      description: 'load test',
      body: 'Lorem ipsum '.repeat(50),
      tagList: ['k6', `t${i % 5}`],
    };
    const r = http.post(`${BASE}/api/articles`, JSON.stringify({ article }), { headers: auth });
    slugs.push(r.json('article.slug'));
  }
  return { token, slugs };
}

export function reader(data) {
  group('browse', () => {
    const list = http.get(`${BASE}/api/articles?limit=10&offset=0`, { tags: { endpoint: 'list_articles' } });
    check(list, { 'list 200': (r) => r.status === 200 });

    const slug = data.slugs[Math.floor(Math.random() * data.slugs.length)];
    const one = http.get(`${BASE}/api/articles/${slug}`, { tags: { endpoint: 'get_article' } });
    check(one, { 'article 200': (r) => r.status === 200 });

    const tags = http.get(`${BASE}/api/tags`, { tags: { endpoint: 'tags' } });
    check(tags, { 'tags 200': (r) => r.status === 200 });
  });
}

export function writer(data) {
  const article = {
    title: `k6 write ${__VU}-${__ITER}-${Date.now()}`,
    description: 'load test',
    body: 'body',
    tagList: ['k6'],
  };
  const res = http.post(`${BASE}/api/articles`, JSON.stringify({ article }), {
    headers: { ...JSON_HEADERS, Authorization: `Token ${data.token}` },
    tags: { endpoint: 'create_article' },
  });
  check(res, { 'create 201': (r) => r.status === 201 });
}

// Machine-readable summary for compare.py, human-readable table in the log.
export function handleSummary(data) {
  const p95 = {};
  for (const [name, metric] of Object.entries(data.metrics)) {
    const m = name.match(/^http_req_duration\{endpoint:(\w+)\}$/);
    if (m) p95[m[1]] = metric.values['p(95)'];
  }
  const out = {
    p95_ms: p95,
    requests: data.metrics.http_reqs.values.count,
    rps: data.metrics.http_reqs.values.rate,
    failed_rate: data.metrics.http_req_failed.values.rate,
  };
  return {
    [__ENV.SUMMARY_PATH || 'perf-summary.json']: JSON.stringify(out, null, 2),
    stdout: `\n${JSON.stringify(out, null, 2)}\n`,
  };
}

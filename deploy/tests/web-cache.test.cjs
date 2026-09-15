const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const root = require('node:path').resolve(__dirname, '../../apps') + '/';
(async () => {
for (const app of ['back_office', 'kds', 'customer_mobile']) {
  const source = fs.readFileSync(root + app + '/web/flutter_bootstrap.js', 'utf8')
    .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
  const deleted = [], unregistered = [], loads = [], errors = [];
  const context = { URL, console: { error: (...args) => errors.push(args) },
    window: { caches: {} }, document: { body: {} },
    caches: { delete: async name => { deleted.push(name); return true; } },
    navigator: { serviceWorker: { getRegistrations: async () => [
      { active: { scriptURL: 'https://example.com/flutter_service_worker.js?v=old' },
        unregister: async () => { unregistered.push('flutter'); } },
      { active: { scriptURL: 'https://example.com/other-worker.js' },
        unregister: async () => { unregistered.push('other'); } },
    ] } },
    _flutter: { loader: { load: async (...args) => {
      assert.equal(deleted.length, 3); loads.push(args);
    } } },
  };
  await vm.runInNewContext(source, context);
  assert.deepEqual(unregistered, ['flutter']);
  assert.equal(loads.length, 1);
  assert.equal(loads[0].length, 0);
  assert.equal(errors.length, 0);
  const callbacks = {};
  const ops = [];
  const worker = { URL,
    caches: { delete: async n => { ops.push(n); } },
    fetch: async (r, options) => { assert.equal(options.cache, 'reload'); return 'network'; },
    self: { location: { origin: 'https://example.com' },
      addEventListener: (name, cb) => callbacks[name] = cb,
      skipWaiting: async () => ops.push('skip'),
      clients: { claim: async () => ops.push('claim') },
      registration: { unregister: async () => ops.push('unregister') },
    },
  };
  vm.runInNewContext(fs.readFileSync(root + app + '/web/retire-service-worker.js', 'utf8'), worker);
  let pending;
  callbacks.install({waitUntil: p => pending = p}); await pending;
  callbacks.activate({waitUntil: p => pending = p}); await pending;
  assert.equal(ops.at(-1), 'unregister');
  assert.equal(ops.filter(x => x.startsWith('flutter-')).length, 3);
  callbacks.fetch({ request: { method: 'GET', url: 'https://example.com/main.dart.js' }, respondWith: p => pending = p });
  assert.equal(await pending, 'network');
  callbacks.fetch({request: {method: 'PATCH', url: 'https://example.com/api'}, respondWith: () => assert.fail('mutation intercepted')});
  console.log(app + ': bootstrap cleanup, no registration, retirement and network bypass PASS');
}
})();

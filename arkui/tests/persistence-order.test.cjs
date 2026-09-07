const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { AppStore, AppSettings } = load('model/AppStore');
(async () => {
  const store = new AppStore(), values = new Map();
  let release, started, first = true, active = 0, peak = 0, fail = false;
  const blocked = new Promise(resolve => { release = resolve; });
  const entered = new Promise(resolve => { started = resolve; });
  store.storage = {
    put: async (key, value) => {
      active++; peak = Math.max(peak, active);
      try {
        if (first) { first = false; started(); await blocked; }
        if (fail) { fail = false; throw new Error('simulated storage failure'); }
        values.set(key, value);
      } finally { active--; }
    }, flush: async () => {},
  };
  store.settings.alias = 'old'; const old = store.save(); await entered;
  store.settings.alias = 'new'; store.favorites = [{ fingerprint: 'new-peer' }];
  store.history = [{ id: 'kept', name: 'new-file' }, { id: 'private', name: 'private-file' }];
  store.persistentHistory = new Set(['kept']);
  const latest = store.save(); release(); assert.deepEqual(await Promise.all([old, latest]), [true, true]);
  assert.equal(JSON.parse(values.get('settings')).alias, 'new');
  assert.equal(JSON.parse(values.get('favorites'))[0].fingerprint, 'new-peer');
  assert.deepEqual(JSON.parse(values.get('history')).map(entry => entry.id), ['kept']);
  assert.equal(peak, 1, 'preference writes must not overlap');
  fail = true; assert.equal(await store.save(), false);
  store.settings.alias = 'after-failure'; assert.equal(await store.save(), true);
  assert.equal(await new AppStore().save(), false, 'uninitialized preferences cannot report a successful save');
  assert.equal(JSON.parse(values.get('settings')).alias, 'after-failure', 'failure must not poison the queue');
  store.settings.fingerprint = 'preserved-identity';
  const saving = store.save(); const restoring = store.restoreSettings(); const following = store.save();
  await saving; assert.equal(await restoring, true); await following;
  assert.equal(JSON.parse(values.get('settings')).alias, new AppSettings().alias);
  assert.equal(store.settings.alias, JSON.parse(values.get('settings')).alias);
  assert.equal(JSON.parse(values.get('settings')).fingerprint, 'preserved-identity');
  const guarded = new AppStore(); let unblock, enteredGuard;
  const guardGate = new Promise(resolve => { unblock = resolve; });
  const guardStarted = new Promise(resolve => { enteredGuard = resolve; });
  guarded.storage = { put: async () => { enteredGuard(); await guardGate; }, flush: async () => {} };
  guarded.settings.alias = 'keep-while-sharing';
  const busySave = guarded.save(); await guardStarted;
  const delayedReset = guarded.restoreSettings(); guarded.webStarting = true;
  unblock(); await busySave;
  assert.equal(await delayedReset, false, 'a queued reset must recheck activity before executing');
  assert.equal(guarded.settings.alias, 'keep-while-sharing');
  console.log('PASS serialized preferences, latest values, private history exclusion, failure recovery and reset ordering');
})().catch(error => { console.error(error); process.exitCode = 1; });

const assert = require('node:assert/strict');
const { load, mocks } = require('./host-runtime.cjs');
mocks['@kit.AbilityKit'].UIAbility = class {};
const { appStore, AppStore, TransferView } = load('model/AppStore');
const EntryAbility = load('entryability/EntryAbility').default;
const { receiveSystemShare, isIncomingWant } = load('platform/IncomingShare');
const { backgroundKeeper } = load('platform/BackgroundKeeper');
(async () => {
  appStore.init = async () => { appStore.ready = true; };
  appStore.privacyAccepted = false;
  const ability = new EntryAbility(); ability.context = {};
  const text = 'Hello 中文\n🙂';
  ability.onCreate({ parameters: { 'aloesend.text': text } }, {});
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(appStore.files.length, 0);
  appStore.privacyAccepted = true; await appStore.onPrivacyAccepted();
  assert.equal(appStore.files[0].text, text); assert.equal(appStore.files[0].size, Buffer.byteLength(text));
  assert.equal(appStore.launchRoute, 'send');
  ability.onNewWant({ parameters: { 'aloesend.route': 'web' } }, {});
  await new Promise(resolve => setImmediate(resolve)); assert.equal(appStore.launchRoute, 'web');
  await receiveSystemShare({ parameters: { 'aloesend.route': 'unknown' } }, appStore);
  assert.equal(appStore.launchRoute, 'web');
  assert.equal(isIncomingWant({ parameters: { 'aloesend.text': 123 } }), false);
  const activity = [], background = [];
  const store = new AppStore(); store.context = {}; store.onTransferActivity = active => activity.push(active);
  const original = backgroundKeeper.sync; backgroundKeeper.sync = async active => background.push(active);
  try {
    const transfer = new TransferView(); transfer.id = 'hash'; transfer.hashing = true;
    store.updateTransfer(transfer); transfer.hashing = false; transfer.status = 'cancelled'; store.updateTransfer(transfer);
    assert.deepEqual(activity, [true, false]); assert.deepEqual(background, [true, false]);
  } finally { backgroundKeeper.sync = original; }
  console.log('PASS cold/warm launch, privacy queue, UTF-8 text and hashing background lifecycle');
})().catch(error => { console.error(error); process.exitCode = 1; });

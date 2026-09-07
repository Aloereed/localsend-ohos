const assert = require('node:assert/strict');
const { load, mocks } = require('./host-runtime.cjs');
const { AppStore, ShareFile } = load('model/AppStore');
const { floatingBarLayout } = load('model/NavigationLayout');
const { flutterLanguages } = load('model/FlutterLocales');
const { uiText } = load('model/Locale');
const picker = mocks['@kit.CoreFileKit'].picker;
picker.DocumentSelectOptions = class {};
picker.PhotoSelectOptions = class {};
picker.DocumentSelectMode = { FILE: 0, FOLDER: 1 };
picker.PhotoViewMIMETypes = { IMAGE_VIDEO_TYPE: '*/*' };
const uris = (start, count) => Array.from({ length: count }, (_, i) => `photo://${start + i}`);
(async () => {
  const store = new AppStore(); store.context = {};
  store.readShareFile = async uri => { const file = new ShareFile(); file.uri = uri; file.name = uri; return file; };
  let documentLimit;
  picker.DocumentViewPicker = class { async select(options) { documentLimit = options.maxSelectNumber; return uris(0, 999); } };
  assert.equal(await store.selectFiles('file'), true); assert.equal(documentLimit, 999); assert.equal(store.files.length, 999);
  assert.equal((await store.selectAttachments('file')).length, 999); assert.equal(documentLimit, 999);
  console.log('PASS file and attachment pickers accept 999 selections');

  let batches, limits, prompts;
  function gallery(values) {
    batches = values; limits = []; prompts = [];
    picker.PhotoViewPicker = class { async select(options) {
      limits.push(options.maxSelectNumber); assert.ok(options.maxSelectNumber >= 1 && options.maxSelectNumber <= 500);
      return { photoUris: batches.shift() || [] };
    } };
    store.onContinuePhotoSelection = async (selected, remaining) => { prompts.push([selected, remaining]); return true; };
  }
  store.files = [];
  gallery([uris(0, 500), uris(500, 499)]);
  assert.equal(await store.selectFiles('photo'), true); assert.equal(store.files.length, 999);
  assert.deepEqual(limits, [500, 499]); assert.deepEqual(prompts, [[500, 499]]);
  assert.equal(store.selectionReadCount, 999); assert.equal(store.busy, false);
  gallery([uris(0, 500), uris(500, 499)]);
  assert.equal((await store.selectAttachments('photo')).length, 999); assert.deepEqual(limits, [500, 499]);
  console.log('PASS gallery and photo attachments reach 999 using valid 500 + 499 system selections');

  gallery([uris(0, 500)]); store.onContinuePhotoSelection = async () => false;
  assert.equal((await store.selectAttachments('photo')).length, 500); assert.deepEqual(limits, [500]);
  gallery([uris(0, 500), []]);
  assert.equal((await store.selectAttachments('photo')).length, 500);
  gallery([uris(0, 500), uris(0, 499)]);
  assert.equal((await store.selectAttachments('photo')).length, 500); assert.equal(limits.length, 2, 'duplicates must not loop forever');
  gallery([uris(0, 10)]);
  assert.equal((await store.selectAttachments('photo')).length, 10); assert.deepEqual(prompts, []);
  const previous = store.files;
  gallery([uris(1000, 500)]); store.onContinuePhotoSelection = async () => { store.cancelSelection(); return true; };
  assert.equal(await store.selectFiles('photo'), false); assert.equal(store.files, previous); assert.equal(store.busy, false);
  console.log('PASS finish early, cancel next batch, duplicates and atomic cancellation preserve the previous selection');

  // Exercise the same instance's large-to-small geometry sequence rather than
  // a single initial phone layout. Both HDS breakpoints receive this geometry.
  for (const width of [1440, 1000, 841, 840, 600, 599, 440, 439, 390, 320, 280, 20, 0, 1280, 360]) {
    const bar = floatingBarLayout(width);
    assert.ok(bar.width >= 0 && bar.width <= 520 && bar.width <= width);
    assert.ok(bar.sideMargin >= 0);
    assert.equal(bar.sideMargin * 2 + bar.width, width);
    if (width >= 32) assert.ok(bar.sideMargin >= 16);
  }
  assert.equal(floatingBarLayout(NaN).width, 0);
  assert.equal(flutterLanguages.find(language => language.id === 'zh-TW').name, '繁體中文');
  assert.equal(uiText('从旧版本导入设置', 'en'), 'Import settings from the previous version');
  console.log('PASS centered bounded navigation through resize breakpoints, language name and import wording');
})().catch(error => { console.error(error); process.exitCode = 1; });

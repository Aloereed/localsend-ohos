const assert = require('node:assert/strict');
const { load } = require('./host-runtime.cjs');
const { HistoryEntry, Peer } = load('model/AppStore');
const { conversationList, inConversation } = load('model/Conversations');
const oldPeer = new Peer(); oldPeer.alias = 'Laptop'; oldPeer.ip = '192.168.1.2'; oldPeer.fingerprint = 'identity-a';
const movedPeer = new Peer(); movedPeer.alias = 'Renamed laptop'; movedPeer.ip = '192.168.1.99'; movedPeer.fingerprint = 'identity-a';
const stranger = new Peer(); stranger.alias = 'Laptop'; stranger.ip = '192.168.1.3'; stranger.fingerprint = 'identity-b';
function entry(peer, time, text) { const item = new HistoryEntry(); item.peer = peer.alias; item.peerInfo = peer; item.time = time; item.text = text; return item; }
const a = entry(oldPeer, 1, 'old'); const b = entry(movedPeer, 3, 'new'); const c = entry(stranger, 2, 'other');
const groups = conversationList([a, c, b]);
assert.equal(groups.length, 2); assert.equal(groups[0].count, 2); assert.equal(groups[0].last.text, 'new');
assert.equal(groups[0].peer.alias, 'Renamed laptop');
assert.equal(inConversation(a, movedPeer), true); assert.equal(inConversation(c, oldPeer), false);
const legacy = new HistoryEntry(); legacy.peer = 'Laptop';
assert.equal(inConversation(legacy, oldPeer), true);
console.log('PASS conversations follow identity across address/name changes, separate same-name devices, sort newest first, and retain legacy history');

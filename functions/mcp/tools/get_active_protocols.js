const {shapeProtocolForMcp} = require("./_protocol_shape");

const NAME = "get_active_protocols";

// Default: skip docs where isActive !== true (covers explicit
// `false`, missing field, or any non-boolean truthy noise). The hard
// constraint from the spec: a doc missing isActive entirely (older
// schema) should be excluded by default — err on the side of NOT
// surfacing possibly-stale data.
async function handler({input, ctx}) {
  const {userRef, now} = ctx;
  const referenceNow = typeof now === "number" ? new Date(now) : new Date();
  const includeRetired = input && input.includeRetired === true;

  const snap = await userRef.collection("protocols").get();
  const protocols = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    if (!includeRetired && data.isActive !== true) continue;
    protocols.push(shapeProtocolForMcp(doc, referenceNow));
  }
  return {protocols};
}

module.exports = {name: NAME, handler};

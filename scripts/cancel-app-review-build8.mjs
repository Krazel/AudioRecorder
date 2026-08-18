import crypto from "node:crypto";
import fs from "node:fs";

const submissionId = "7e9fd837-4419-498a-a40a-7e8fbbd4422e";
const versionId = "19fcd264-9dc6-4a30-99f9-d172a46ce686";
const build8Id = "8c9700dc-6582-42c4-aa07-cf857c1d43d5";
const expectedRelatedIds = new Set([
  versionId,
  "f0b147b9-e634-4e15-9b10-c6007827d8f7",
  "4711a2eb-cdc0-4cc7-89ed-731ad6330c97",
  "57de84b5-c7dd-41c9-be74-02fc22dc3427",
  "2b9e7d5c-6cb8-409b-b5a2-bbc842812365",
  "421cef00-2cf2-4981-9fb4-5952b087a865",
  "1fb8ba48-fe0c-491f-a685-8275346e123a",
  "7edb64cf-f090-4aa2-901b-05dab37ee22e",
  "492cf983-5f2d-4479-a9b5-e3972de5d477"
]);
const mode = process.argv[2] ?? "status";

if (!new Set(["status", "cancel"]).has(mode)) {
  fail("Usage: node scripts/cancel-app-review-build8.mjs [status|cancel] [--confirm-cancel]");
}
if (mode === "cancel" && process.argv[3] !== "--confirm-cancel") {
  fail("Cancellation requires --confirm-cancel.");
}

const token = createToken({
  keyId: requiredEnvironment("ASC_KEY_ID"),
  issuerId: requiredEnvironment("ASC_ISSUER_ID"),
  privateKey: fs.readFileSync(requiredEnvironment("ASC_PRIVATE_KEY_PATH"), "utf8")
});

const before = await snapshot();
assertExpected(before);

if (before.submissionState === "COMPLETE" && before.versionState === "DEVELOPER_REJECTED") {
  console.log(JSON.stringify({ status: "ALREADY_CANCELED", ...before }, null, 2));
  process.exit(0);
}
if (!new Set(["WAITING_FOR_REVIEW", "IN_REVIEW"]).has(before.submissionState)) {
  fail(`Submission is not cancelable from its current state: ${before.submissionState}.`);
}
if (before.selectedBuildId !== build8Id) fail("Build 8 is not selected; refusing to cancel.");
if (before.releaseType !== "MANUAL") fail("Release type is not MANUAL.");

if (mode === "status") {
  console.log(JSON.stringify({ status: "READY_TO_CANCEL", ...before }, null, 2));
  process.exit(0);
}

await request("PATCH", `/v1/reviewSubmissions/${submissionId}`, {
  data: {
    type: "reviewSubmissions",
    id: submissionId,
    attributes: { canceled: true }
  }
});

const canceled = await waitFor(async () => {
  const current = await snapshot();
  return current.submissionState === "COMPLETE" && current.versionState === "DEVELOPER_REJECTED"
    ? current
    : false;
});
assertExpected(canceled);
console.log(JSON.stringify({ status: "CANCELED_FOR_BUILD_9", ...canceled }, null, 2));

async function snapshot() {
  const [version, submission, itemsResponse] = await Promise.all([
    request("GET", `/v1/appStoreVersions/${versionId}?include=build`),
    request("GET", `/v1/reviewSubmissions/${submissionId}`),
    request("GET", `/v1/reviewSubmissions/${submissionId}/items?include=appStoreVersion,subscriptionVersion,subscriptionGroupVersion&limit=200`)
  ]);
  const included = new Map((itemsResponse.included ?? []).map((item) => [`${item.type}:${item.id}`, item]));
  const relationshipNames = ["appStoreVersion", "subscriptionVersion", "subscriptionGroupVersion"];
  const items = (itemsResponse.data ?? []).map((item) => {
    const relationship = relationshipNames.map((name) => item.relationships?.[name]?.data).find(Boolean);
    const related = relationship ? included.get(`${relationship.type}:${relationship.id}`) : undefined;
    return {
      id: item.id,
      relatedId: relationship?.id ?? null,
      relatedType: relationship?.type ?? null,
      itemState: item.attributes?.state,
      relatedState: related?.attributes?.state ?? related?.attributes?.appVersionState ?? null
    };
  });
  return {
    submissionState: submission.data.attributes?.state,
    versionState: version.data.attributes?.appVersionState,
    selectedBuildId: version.data.relationships?.build?.data?.id ?? null,
    releaseType: version.data.attributes?.releaseType,
    usesIdfa: version.data.attributes?.usesIdfa,
    itemCount: items.length,
    items
  };
}

function assertExpected(value) {
  if (value.itemCount !== 9) fail(`Expected 9 items; found ${value.itemCount}.`);
  const actual = new Set(value.items.map((item) => item.relatedId));
  if (actual.size !== expectedRelatedIds.size || [...expectedRelatedIds].some((id) => !actual.has(id))) {
    fail(`Submission contents changed unexpectedly: ${JSON.stringify(value.items)}`);
  }
  if (value.usesIdfa !== true) fail("usesIdfa must remain true.");
}

async function waitFor(check) {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const result = await check();
    if (result) return result;
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
  fail("Timed out waiting for cancellation.");
}

async function request(method, endpoint, body) {
  const response = await fetch(`https://api.appstoreconnect.apple.com${endpoint}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body ? { "Content-Type": "application/json" } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : {};
  if (!response.ok) fail(`App Store Connect API failed ${method} ${endpoint}: ${response.status} ${text}`);
  return json;
}

function createToken({ keyId, issuerId, privateKey }) {
  const now = Math.floor(Date.now() / 1000);
  const input = `${base64url(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" }))}.${base64url(JSON.stringify({
    iss: issuerId,
    aud: "appstoreconnect-v1",
    exp: now + 19 * 60,
    iat: now
  }))}`;
  const signer = crypto.createSign("SHA256");
  signer.update(input);
  signer.end();
  return `${input}.${base64url(signer.sign({ key: privateKey, dsaEncoding: "ieee-p1363" }))}`;
}

function base64url(value) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value);
  return buffer.toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function requiredEnvironment(name) {
  const value = process.env[name]?.trim();
  if (!value) fail(`Missing ${name}.`);
  return value;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

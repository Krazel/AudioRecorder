import crypto from "node:crypto";
import fs from "node:fs";

const appId = "6772278149";
const bundleId = "com.dmkr.audio.B2X6D3A9J9";
const versionId = "19fcd264-9dc6-4a30-99f9-d172a46ce686";
const submissionId = "7e9fd837-4419-498a-a40a-7e8fbbd4422e";
const rejectedItemId = "N2U5ZmQ4MzctNDQxOS00OThhLWE0MGEtN2U4ZmJiZDQ0MjJlfDZ8ODg2MDI4ODkw";
const buildNumber = "7";
const mode = process.argv[2] ?? "status";

if (!new Set(["status", "apply"]).has(mode)) {
  fail("Usage: node scripts/complete-app-review-build7.mjs [status|apply] [--confirm-resubmit]");
}
if (mode === "apply" && process.argv[3] !== "--confirm-resubmit") {
  fail("Resubmission requires --confirm-resubmit.");
}

const keyId = requiredEnvironment("ASC_KEY_ID");
const issuerId = requiredEnvironment("ASC_ISSUER_ID");
const privateKeyPath = requiredEnvironment("ASC_PRIVATE_KEY_PATH");
const token = createToken({
  keyId,
  issuerId,
  privateKey: fs.readFileSync(privateKeyPath, "utf8")
});

const app = (await request("GET", `/v1/apps/${appId}`)).data;
if (app?.attributes?.bundleId !== bundleId) {
  fail(`App ${appId} is not the expected bundle ${bundleId}.`);
}

const buildQuery = new URLSearchParams({
  "filter[app]": appId,
  "filter[version]": buildNumber,
  "fields[builds]": "version,uploadedDate,expired,processingState,buildAudienceType,usesNonExemptEncryption",
  limit: "10"
});
const builds = (await request("GET", `/v1/builds?${buildQuery}`)).data ?? [];
if (builds.length !== 1) {
  fail(`Expected exactly one build ${buildNumber}; found ${builds.length}.`);
}
const build = builds[0];
if (
  build.attributes?.processingState !== "VALID" ||
  build.attributes?.buildAudienceType !== "APP_STORE_ELIGIBLE" ||
  build.attributes?.expired === true
) {
  fail(`Build 7 is not a valid App Store candidate: ${JSON.stringify(build.attributes)}`);
}

const preReleaseVersion = await request("GET", `/v1/builds/${build.id}/preReleaseVersion`);
if (preReleaseVersion.data?.attributes?.version !== "1.0") {
  fail("Build 7 does not belong to marketing version 1.0.");
}

const before = await snapshot();
if (
  before.submissionState === "WAITING_FOR_REVIEW" &&
  before.versionState === "WAITING_FOR_REVIEW" &&
  before.items.every((item) => item.relatedState === "WAITING_FOR_REVIEW")
) {
  assertSubmissionShape(before, { requireWaiting: true });
  console.log(JSON.stringify({ status: "ALREADY_RESUBMITTED", build: publicBuild(build), ...before }, null, 2));
  process.exit(0);
}
assertSubmissionShape(before, { allowRejectedApp: true });
if (mode === "status") {
  console.log(JSON.stringify({ status: "READY_TO_APPLY", build: publicBuild(build), ...before }, null, 2));
  process.exit(0);
}

if (before.selectedBuildId !== build.id) {
  await request("PATCH", `/v1/appStoreVersions/${versionId}/relationships/build`, {
    data: { type: "builds", id: build.id }
  });
}

await waitFor("build 7 selection", async () => {
  const versionBuild = await request("GET", `/v1/appStoreVersions/${versionId}/relationships/build`);
  return versionBuild.data?.id === build.id;
});

const selectedVersion = (await request("GET", `/v1/appStoreVersions/${versionId}`)).data;
if (selectedVersion.attributes?.usesIdfa !== true) fail("usesIdfa must remain true.");
if (selectedVersion.attributes?.releaseType !== "MANUAL") fail("Release type must remain MANUAL.");

const appItemBeforeResolve = before.items.find((candidate) => candidate.id === rejectedItemId);
if (appItemBeforeResolve?.itemState === "REJECTED") {
  await request("PATCH", `/v1/reviewSubmissionItems/${rejectedItemId}`, {
    data: {
      type: "reviewSubmissionItems",
      id: rejectedItemId,
      attributes: { resolved: true }
    }
  });
} else if (appItemBeforeResolve?.itemState !== "READY_FOR_REVIEW") {
  fail(`Unexpected app review item state: ${appItemBeforeResolve?.itemState ?? "missing"}.`);
}

await waitFor("resolved app item", async () => {
  const current = await snapshot();
  const item = current.items.find((candidate) => candidate.id === rejectedItemId);
  return item?.itemState === "READY_FOR_REVIEW";
});

const ready = await snapshot();
assertSubmissionShape(ready, { allowRejectedApp: false });

await request("PATCH", `/v1/reviewSubmissions/${submissionId}`, {
  data: {
    type: "reviewSubmissions",
    id: submissionId,
    attributes: { submitted: true }
  }
});

const submitted = await waitFor("submitted review", async () => {
  const current = await snapshot();
  const allRelatedWaiting = current.items.every((item) => item.relatedState === "WAITING_FOR_REVIEW");
  return (
    current.submissionState === "WAITING_FOR_REVIEW" &&
    current.versionState === "WAITING_FOR_REVIEW" &&
    allRelatedWaiting
  ) ? current : false;
});
assertSubmissionShape(submitted, { requireWaiting: true });

console.log(JSON.stringify({ status: "RESUBMITTED", build: publicBuild(build), ...submitted }, null, 2));

async function snapshot() {
  const [version, submission, itemsResponse] = await Promise.all([
    request("GET", `/v1/appStoreVersions/${versionId}?include=build`),
    request("GET", `/v1/reviewSubmissions/${submissionId}`),
    request(
      "GET",
      `/v1/reviewSubmissions/${submissionId}/items?include=appStoreVersion,subscriptionVersion,subscriptionGroupVersion&limit=200`
    )
  ]);
  const included = new Map(
    (itemsResponse.included ?? []).map((item) => [`${item.type}:${item.id}`, item])
  );
  const relationshipNames = ["appStoreVersion", "subscriptionVersion", "subscriptionGroupVersion"];
  const items = (itemsResponse.data ?? []).map((item) => {
    const relationship = relationshipNames
      .map((name) => item.relationships?.[name]?.data)
      .find(Boolean);
    const related = relationship ? included.get(`${relationship.type}:${relationship.id}`) : undefined;
    return {
      id: item.id,
      itemState: item.attributes?.state,
      relatedType: relationship?.type ?? null,
      relatedState: related?.attributes?.state ?? related?.attributes?.appVersionState ?? null
    };
  });
  return {
    versionState: version.data.attributes?.appVersionState,
    usesIdfa: version.data.attributes?.usesIdfa,
    releaseType: version.data.attributes?.releaseType,
    selectedBuildId: version.data.relationships?.build?.data?.id ?? null,
    submissionState: submission.data.attributes?.state,
    itemCount: items.length,
    items
  };
}

function assertSubmissionShape(snapshotValue, options) {
  if (snapshotValue.itemCount !== 9) fail(`Expected 9 submission items; found ${snapshotValue.itemCount}.`);
  const appItems = snapshotValue.items.filter((item) => item.relatedType === "appStoreVersions");
  const subscriptionItems = snapshotValue.items.filter((item) => item.relatedType === "subscriptionVersions");
  const groupItems = snapshotValue.items.filter((item) => item.relatedType === "subscriptionGroupVersions");
  if (appItems.length !== 1 || subscriptionItems.length !== 7 || groupItems.length !== 1) {
    fail(`Unexpected submission composition: ${JSON.stringify(snapshotValue.items)}`);
  }
  if (options.requireWaiting) {
    if (snapshotValue.submissionState !== "WAITING_FOR_REVIEW") fail("Submission is not waiting for review.");
    if (snapshotValue.versionState !== "WAITING_FOR_REVIEW") fail("App version is not waiting for review.");
    if (snapshotValue.items.some((item) => item.relatedState !== "WAITING_FOR_REVIEW")) {
      fail("Not every related review resource is waiting for review.");
    }
  } else if (!options.allowRejectedApp) {
    if (snapshotValue.items.some((item) => item.itemState !== "READY_FOR_REVIEW")) {
      fail("Not every submission item is ready for review.");
    }
  }
}

async function waitFor(label, check) {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    const result = await check();
    if (result) return result;
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
  fail(`Timed out waiting for ${label}.`);
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
  const responseText = await response.text();
  const json = responseText ? JSON.parse(responseText) : {};
  if (!response.ok) {
    fail(`App Store Connect API failed ${method} ${endpoint}: ${response.status} ${responseText}`);
  }
  return json;
}

function publicBuild(value) {
  return {
    id: value.id,
    buildNumber: value.attributes?.version,
    processingState: value.attributes?.processingState,
    buildAudienceType: value.attributes?.buildAudienceType,
    expired: value.attributes?.expired,
    uploadedDate: value.attributes?.uploadedDate
  };
}

function createToken({ keyId: tokenKeyId, issuerId: tokenIssuerId, privateKey }) {
  const now = Math.floor(Date.now() / 1000);
  const input = `${base64url(JSON.stringify({ alg: "ES256", kid: tokenKeyId, typ: "JWT" }))}.${base64url(JSON.stringify({
    iss: tokenIssuerId,
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

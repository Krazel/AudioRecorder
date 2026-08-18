import crypto from "node:crypto";
import fs from "node:fs";

const appId = "6772278149";
const bundleId = "com.dmkr.audio.B2X6D3A9J9";
const versionId = "19fcd264-9dc6-4a30-99f9-d172a46ce686";
const reviewDetailId = "bb50ebf4-eb49-4313-993d-74e174572d1a";
const submissionId = "7e9fd837-4419-498a-a40a-7e8fbbd4422e";
const rejectedItemId = "N2U5ZmQ4MzctNDQxOS00OThhLWE0MGEtN2U4ZmJiZDQ0MjJlfDZ8ODg2MDI4ODkw";
const buildNumber = "8";
const expectedSubscriptionVersionIds = new Set([
  "4711a2eb-cdc0-4cc7-89ed-731ad6330c97",
  "57de84b5-c7dd-41c9-be74-02fc22dc3427",
  "2b9e7d5c-6cb8-409b-b5a2-bbc842812365",
  "421cef00-2cf2-4981-9fb4-5952b087a865",
  "1fb8ba48-fe0c-491f-a685-8275346e123a",
  "7edb64cf-f090-4aa2-901b-05dab37ee22e",
  "492cf983-5f2d-4479-a9b5-e3972de5d477"
]);
const expectedSubscriptionGroupVersionId = "f0b147b9-e634-4e15-9b10-c6007827d8f7";
const mode = process.argv[2] ?? "status";

if (!new Set(["status", "apply"]).has(mode)) {
  fail("Usage: node scripts/complete-app-review-build8.mjs [status|apply] [--confirm-resubmit]");
}
if (mode === "apply" && process.argv[3] !== "--confirm-resubmit") {
  fail("Resubmission requires --confirm-resubmit.");
}

const token = createToken({
  keyId: requiredEnvironment("ASC_KEY_ID"),
  issuerId: requiredEnvironment("ASC_ISSUER_ID"),
  privateKey: fs.readFileSync(requiredEnvironment("ASC_PRIVATE_KEY_PATH"), "utf8")
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
  fail(`Build 8 is not a valid App Store candidate: ${JSON.stringify(build.attributes)}`);
}

const preReleaseVersion = await request("GET", `/v1/builds/${build.id}/preReleaseVersion`);
if (preReleaseVersion.data?.attributes?.version !== "1.0") {
  fail("Build 8 does not belong to marketing version 1.0.");
}

const before = await snapshot();
if (
  before.submissionState === "WAITING_FOR_REVIEW" &&
  before.versionState === "WAITING_FOR_REVIEW" &&
  before.selectedBuildId === build.id &&
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

await waitFor("build 8 selection", async () => {
  const relationship = await request("GET", `/v1/appStoreVersions/${versionId}/relationships/build`);
  return relationship.data?.id === build.id;
});

const selectedVersion = (await request("GET", `/v1/appStoreVersions/${versionId}`)).data;
if (selectedVersion.attributes?.usesIdfa !== true) fail("usesIdfa must remain true.");
if (selectedVersion.attributes?.releaseType !== "MANUAL") fail("Release type must remain MANUAL.");

const reviewNotes = buildReviewNotes();
await request("PATCH", `/v1/appStoreReviewDetails/${reviewDetailId}`, {
  data: {
    type: "appStoreReviewDetails",
    id: reviewDetailId,
    attributes: { notes: reviewNotes }
  }
});

const savedReviewDetail = (await request("GET", `/v1/appStoreReviewDetails/${reviewDetailId}`)).data;
if (savedReviewDetail.attributes?.notes !== reviewNotes) {
  fail("App Review Notes did not persist exactly.");
}

const beforeResolve = await snapshot();
assertSubmissionShape(beforeResolve, { allowRejectedApp: true });
if (beforeResolve.selectedBuildId !== build.id) fail("Build 8 selection was lost before resolve.");

const appItem = beforeResolve.items.find((candidate) => candidate.id === rejectedItemId);
if (appItem?.itemState === "REJECTED") {
  await request("PATCH", `/v1/reviewSubmissionItems/${rejectedItemId}`, {
    data: {
      type: "reviewSubmissionItems",
      id: rejectedItemId,
      attributes: { resolved: true }
    }
  });
} else if (appItem?.itemState !== "READY_FOR_REVIEW") {
  fail(`Unexpected app review item state: ${appItem?.itemState ?? "missing"}.`);
}

await waitFor("resolved app item", async () => {
  const current = await snapshot();
  return current.items.find((candidate) => candidate.id === rejectedItemId)?.itemState === "READY_FOR_REVIEW";
});

const ready = await snapshot();
assertSubmissionShape(ready, { allowRejectedApp: false });
if (ready.selectedBuildId !== build.id) fail("Build 8 is not selected at the final gate.");
if (ready.usesIdfa !== true) fail("usesIdfa changed before submission.");
if (ready.releaseType !== "MANUAL") fail("Release type changed before submission.");

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
    current.selectedBuildId === build.id &&
    allRelatedWaiting
  ) ? current : false;
});
assertSubmissionShape(submitted, { requireWaiting: true });

console.log(JSON.stringify({ status: "RESUBMITTED", build: publicBuild(build), ...submitted }, null, 2));

function buildReviewNotes() {
  return `PURPOSE AND AUDIENCE

Voice Recorder Pro - Audio K is an iPhone utility for people who want to record voice notes, meetings, ideas, and everyday audio locally on their device. No account or login is required.

CORE REVIEW FLOW

1. Launch the app and grant microphone access when recording is first requested.
2. Tap Record to start or stop a recording. The sound-activated mode and quality/segment controls are available in Settings.
3. Open Files to play, rename, favorite, delete, or manually share a recording.
4. Open Settings > Support the app to review the optional monthly subscriptions, restore purchases, manage a subscription, and open Privacy Policy and Terms of Use.

SUBSCRIPTIONS

The optional auto-renewable monthly subscriptions remove ads while active. They do not unlock or block core recording features. All seven displayed levels provide the same ad-removal benefit at different voluntary support prices. The No ads (Audio K Support Monthly 50 v2) price of USD 44.99 per month is intentional. Purchases and restoration use Apple StoreKit only.

PRIVACY AND ATT REVIEW PATH

1. Delete and reinstall build 8, then launch it while online.
2. In the EEA/UK/Switzerland privacy flow, choose Do not consent in the Google UMP European message. Apple's ATT prompt is not shown. The recorder remains fully usable, and only the ad-serving mode permitted by the user's UMP choices may run.
3. On the European consent path, ATT is considered only when the stored TCF choices affirmatively permit personalized advertising for Google. Missing, incomplete, denied, or malformed signals fail closed and do not show ATT.
4. If ATT is shown and the user selects Ask App Not to Track, the app remains fully usable and Google Mobile Ads does not receive IDFA or perform tracking. If ATT is authorized, Google may use IDFA for personalized advertising and advertising measurement as disclosed.
5. Outside the European scope, ATT may be requested after the UMP privacy-status update when Apple's authorization status is still undetermined.
6. When required, Settings > Privacy Options lets the user change the applicable UMP choices. A privacy-options change is not immediately followed by ATT.

EXTERNAL SERVICES AND REGIONAL BEHAVIOR

The app uses Apple StoreKit for subscriptions and Google Mobile Ads/UMP for advertising and consent. Recordings remain on device unless the user manually shares them. The recording features are consistent across regions; only the legally applicable Google privacy message and ATT eligibility differ as described above.

CHANGES IN BUILD 8

Build 8 fixes the issue identified under Guideline 5.1.1(iv). Build 7 incorrectly used UMP canRequestAds as a signal to request ATT, although that value can also allow limited or non-personalized ads after a European refusal. Build 8 removes that behavior and adds an explicit fail-closed eligibility check based on the applicable UMP/TCF choices. A European refusal is not followed by ATT. canRequestAds is used only to determine whether Google Mobile Ads may start.

Privacy Policy: https://krazel.github.io/audio-recorder/privacy/
Support: https://krazel.github.io/audio-recorder/support/
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`;
}

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
      itemState: item.attributes?.state,
      relatedId: relationship?.id ?? null,
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

function assertSubmissionShape(value, options) {
  if (value.itemCount !== 9) fail(`Expected 9 submission items; found ${value.itemCount}.`);
  const appItems = value.items.filter((item) => item.relatedType === "appStoreVersions");
  const subscriptions = value.items.filter((item) => item.relatedType === "subscriptionVersions");
  const groups = value.items.filter((item) => item.relatedType === "subscriptionGroupVersions");
  if (appItems.length !== 1 || subscriptions.length !== 7 || groups.length !== 1) {
    fail(`Unexpected submission composition: ${JSON.stringify(value.items)}`);
  }
  if (appItems[0].id !== rejectedItemId || appItems[0].relatedId !== versionId) {
    fail("The app review item or version changed unexpectedly.");
  }
  const actualSubscriptionIds = new Set(subscriptions.map((item) => item.relatedId));
  if (
    actualSubscriptionIds.size !== expectedSubscriptionVersionIds.size ||
    [...expectedSubscriptionVersionIds].some((id) => !actualSubscriptionIds.has(id))
  ) {
    fail(`Subscription versions changed unexpectedly: ${JSON.stringify(subscriptions)}`);
  }
  if (groups[0].relatedId !== expectedSubscriptionGroupVersionId) {
    fail(`Subscription group version changed unexpectedly: ${JSON.stringify(groups[0])}`);
  }
  if (options.requireWaiting) {
    if (value.submissionState !== "WAITING_FOR_REVIEW") fail("Submission is not waiting for review.");
    if (value.versionState !== "WAITING_FOR_REVIEW") fail("App version is not waiting for review.");
    if (value.items.some((item) => item.relatedState !== "WAITING_FOR_REVIEW")) {
      fail("Not every related review resource is waiting for review.");
    }
  } else if (!options.allowRejectedApp && value.items.some((item) => item.itemState !== "READY_FOR_REVIEW")) {
    fail("Not every submission item is ready for review.");
  }
}

async function waitFor(label, check) {
  for (let attempt = 0; attempt < 60; attempt += 1) {
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
  if (!response.ok) fail(`App Store Connect API failed ${method} ${endpoint}: ${response.status} ${responseText}`);
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

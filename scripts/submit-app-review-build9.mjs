import crypto from "node:crypto";
import fs from "node:fs";

const appId = "6772278149";
const bundleId = "com.dmkr.audio.B2X6D3A9J9";
const versionId = "19fcd264-9dc6-4a30-99f9-d172a46ce686";
const reviewDetailId = "bb50ebf4-eb49-4313-993d-74e174572d1a";
const buildNumber = "9";
const relatedResources = [
  { relationship: "appStoreVersion", type: "appStoreVersions", id: versionId },
  { relationship: "subscriptionGroupVersion", type: "subscriptionGroupVersions", id: "f0b147b9-e634-4e15-9b10-c6007827d8f7" },
  { relationship: "subscriptionVersion", type: "subscriptionVersions", id: "4711a2eb-cdc0-4cc7-89ed-731ad6330c97" },
  { relationship: "subscriptionVersion", type: "subscriptionVersions", id: "57de84b5-c7dd-41c9-be74-02fc22dc3427" },
  { relationship: "subscriptionVersion", type: "subscriptionVersions", id: "2b9e7d5c-6cb8-409b-b5a2-bbc842812365" },
  { relationship: "subscriptionVersion", type: "subscriptionVersions", id: "421cef00-2cf2-4981-9fb4-5952b087a865" },
  { relationship: "subscriptionVersion", type: "subscriptionVersions", id: "1fb8ba48-fe0c-491f-a685-8275346e123a" },
  { relationship: "subscriptionVersion", type: "subscriptionVersions", id: "7edb64cf-f090-4aa2-901b-05dab37ee22e" },
  { relationship: "subscriptionVersion", type: "subscriptionVersions", id: "492cf983-5f2d-4479-a9b5-e3972de5d477" }
];
const expectedRelatedIds = new Set(relatedResources.map((value) => value.id));
const mode = process.argv[2] ?? "status";

if (!new Set(["status", "apply"]).has(mode)) {
  fail("Usage: node scripts/submit-app-review-build9.mjs [status|apply] [--confirm-submit]");
}
if (mode === "apply" && process.argv[3] !== "--confirm-submit") {
  fail("Submission requires --confirm-submit.");
}

const token = createToken({
  keyId: requiredEnvironment("ASC_KEY_ID"),
  issuerId: requiredEnvironment("ASC_ISSUER_ID"),
  privateKey: fs.readFileSync(requiredEnvironment("ASC_PRIVATE_KEY_PATH"), "utf8")
});

const app = (await request("GET", `/v1/apps/${appId}`)).data;
if (app?.attributes?.bundleId !== bundleId) fail(`Unexpected bundle: ${app?.attributes?.bundleId}.`);

const build = await exactBuild9();
const before = await globalSnapshot(build.id);
if (before.submittedSubmission) {
  console.log(JSON.stringify({ status: "ALREADY_SUBMITTED", build: publicBuild(build), ...before }, null, 2));
  process.exit(0);
}
if (mode === "status") {
  console.log(JSON.stringify({ status: "READY_TO_APPLY", build: publicBuild(build), ...before }, null, 2));
  process.exit(0);
}

if (before.version.releaseType !== "MANUAL") fail("Release type must remain MANUAL.");
if (before.version.usesIdfa !== true) fail("usesIdfa must remain true.");

if (before.version.selectedBuildId !== build.id) {
  await request("PATCH", `/v1/appStoreVersions/${versionId}/relationships/build`, {
    data: { type: "builds", id: build.id }
  });
}
await waitFor("build 9 selection", async () => {
  const relationship = await request("GET", `/v1/appStoreVersions/${versionId}/relationships/build`);
  return relationship.data?.id === build.id;
});

const selectedVersion = (await request("GET", `/v1/appStoreVersions/${versionId}`)).data;
if (selectedVersion.attributes?.releaseType !== "MANUAL") fail("Release type changed.");
if (selectedVersion.attributes?.usesIdfa !== true) fail("usesIdfa changed.");

const notes = buildReviewNotes();
await request("PATCH", `/v1/appStoreReviewDetails/${reviewDetailId}`, {
  data: { type: "appStoreReviewDetails", id: reviewDetailId, attributes: { notes } }
});
const savedNotes = (await request("GET", `/v1/appStoreReviewDetails/${reviewDetailId}`)).data.attributes?.notes;
if (savedNotes !== notes) fail("Review notes did not persist exactly.");

let draft = await findReusableDraft();
if (!draft) {
  draft = (await request("POST", "/v1/reviewSubmissions", {
    data: {
      type: "reviewSubmissions",
      relationships: { app: { data: { type: "apps", id: appId } } }
    }
  })).data;
}

let draftSnapshot = await submissionSnapshot(draft.id);
const existingIds = new Set(draftSnapshot.items.map((item) => item.relatedId));
if (draftSnapshot.items.some((item) => !expectedRelatedIds.has(item.relatedId))) {
  fail(`Draft contains an unexpected item: ${JSON.stringify(draftSnapshot.items)}`);
}

for (const resource of relatedResources) {
  if (existingIds.has(resource.id)) continue;
  await request("POST", "/v1/reviewSubmissionItems", {
    data: {
      type: "reviewSubmissionItems",
      relationships: {
        reviewSubmission: { data: { type: "reviewSubmissions", id: draft.id } },
        [resource.relationship]: { data: { type: resource.type, id: resource.id } }
      }
    }
  });
}

draftSnapshot = await waitFor("nine draft items", async () => {
  const current = await submissionSnapshot(draft.id);
  return current.items.length === 9 ? current : false;
});
assertExpectedItems(draftSnapshot.items);
if (draftSnapshot.state !== "READY_FOR_REVIEW") fail(`Draft is not ready: ${draftSnapshot.state}.`);
if (draftSnapshot.items.some((item) => item.itemState !== "READY_FOR_REVIEW")) {
  fail(`A submission item is not ready: ${JSON.stringify(draftSnapshot.items)}`);
}

const finalVersion = (await request("GET", `/v1/appStoreVersions/${versionId}?include=build`)).data;
if (finalVersion.relationships?.build?.data?.id !== build.id) fail("Build 9 selection was lost.");
if (finalVersion.attributes?.releaseType !== "MANUAL") fail("Release type changed before submission.");
if (finalVersion.attributes?.usesIdfa !== true) fail("usesIdfa changed before submission.");

await request("PATCH", `/v1/reviewSubmissions/${draft.id}`, {
  data: { type: "reviewSubmissions", id: draft.id, attributes: { submitted: true } }
});

const submitted = await waitFor("review queue", async () => {
  const current = await submissionSnapshot(draft.id);
  return new Set(["WAITING_FOR_REVIEW", "IN_REVIEW"]).has(current.state) ? current : false;
});
assertExpectedItems(submitted.items);

console.log(JSON.stringify({
  status: "SUBMITTED_BUILD_9",
  build: publicBuild(build),
  submissionId: draft.id,
  submissionState: submitted.state,
  itemCount: submitted.items.length,
  items: submitted.items
}, null, 2));

async function exactBuild9() {
  const query = new URLSearchParams({
    "filter[app]": appId,
    "filter[version]": buildNumber,
    "fields[builds]": "version,uploadedDate,expired,processingState,buildAudienceType,usesNonExemptEncryption",
    limit: "10"
  });
  const builds = (await request("GET", `/v1/builds?${query}`)).data ?? [];
  if (builds.length !== 1) fail(`Expected exactly one build 9; found ${builds.length}.`);
  const value = builds[0];
  if (
    value.attributes?.processingState !== "VALID" ||
    value.attributes?.buildAudienceType !== "APP_STORE_ELIGIBLE" ||
    value.attributes?.expired === true
  ) {
    fail(`Build 9 is not valid: ${JSON.stringify(value.attributes)}`);
  }
  const prerelease = await request("GET", `/v1/builds/${value.id}/preReleaseVersion`);
  if (prerelease.data?.attributes?.version !== "1.0") fail("Build 9 is not marketing version 1.0.");
  return value;
}

async function globalSnapshot(expectedBuildId) {
  const [versionResponse, submissionsResponse] = await Promise.all([
    request("GET", `/v1/appStoreVersions/${versionId}?include=build`),
    request("GET", `/v1/apps/${appId}/reviewSubmissions?limit=200`)
  ]);
  const version = versionResponse.data;
  const submissions = submissionsResponse.data ?? [];
  let submittedSubmission = null;
  for (const submission of submissions) {
    if (!new Set(["WAITING_FOR_REVIEW", "IN_REVIEW"]).has(submission.attributes?.state)) continue;
    const current = await submissionSnapshot(submission.id);
    const relatedIds = new Set(current.items.map((item) => item.relatedId));
    if (relatedIds.has(versionId)) {
      if (version.relationships?.build?.data?.id !== expectedBuildId) {
        fail("An active app submission exists with a build other than build 9.");
      }
      assertExpectedItems(current.items);
      submittedSubmission = { id: submission.id, state: submission.attributes?.state, items: current.items };
      break;
    }
  }
  return {
    version: {
      state: version.attributes?.appVersionState,
      usesIdfa: version.attributes?.usesIdfa,
      releaseType: version.attributes?.releaseType,
      selectedBuildId: version.relationships?.build?.data?.id ?? null
    },
    submittedSubmission
  };
}

async function findReusableDraft() {
  const submissions = (await request("GET", `/v1/apps/${appId}/reviewSubmissions?limit=200`)).data ?? [];
  const drafts = submissions.filter((value) => value.attributes?.state === "READY_FOR_REVIEW");
  if (drafts.length > 1) fail(`Expected at most one draft; found ${drafts.length}.`);
  return drafts[0] ?? null;
}

async function submissionSnapshot(submissionId) {
  const [submission, itemsResponse] = await Promise.all([
    request("GET", `/v1/reviewSubmissions/${submissionId}`),
    request("GET", `/v1/reviewSubmissions/${submissionId}/items?include=appStoreVersion,subscriptionVersion,subscriptionGroupVersion&limit=200`)
  ]);
  const included = new Map((itemsResponse.included ?? []).map((item) => [`${item.type}:${item.id}`, item]));
  const names = ["appStoreVersion", "subscriptionVersion", "subscriptionGroupVersion"];
  const items = (itemsResponse.data ?? []).map((item) => {
    const relationship = names.map((name) => item.relationships?.[name]?.data).find(Boolean);
    const related = relationship ? included.get(`${relationship.type}:${relationship.id}`) : undefined;
    return {
      id: item.id,
      itemState: item.attributes?.state,
      relatedId: relationship?.id ?? null,
      relatedType: relationship?.type ?? null,
      relatedState: related?.attributes?.state ?? related?.attributes?.appVersionState ?? null
    };
  });
  return { state: submission.data.attributes?.state, items };
}

function assertExpectedItems(items) {
  if (items.length !== 9) fail(`Expected 9 items; found ${items.length}.`);
  const actual = new Set(items.map((item) => item.relatedId));
  if (actual.size !== expectedRelatedIds.size || [...expectedRelatedIds].some((id) => !actual.has(id))) {
    fail(`Submission contents changed unexpectedly: ${JSON.stringify(items)}`);
  }
}

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

RESPONSE TO GUIDELINE 5.1.1(iv)

Thank you for identifying the issue in build 7. That build incorrectly used UMP canRequestAds as a signal to request ATT, although canRequestAds can also allow limited or non-personalized ads after a European refusal. Builds 8 and 9 remove that behavior. In the European flow, selecting Do not consent does not show ATT. Missing, incomplete, denied, malformed, or failed consent signals also do not show ATT. ATT is considered only when the stored UMP/TCF choices affirmatively permit personalized advertising for Google. canRequestAds is used only to determine whether Google Mobile Ads may start.

PRIVACY AND ATT REVIEW PATH

1. Delete and reinstall build 9, then launch it while online.
2. In the EEA/UK/Switzerland flow, choose Do not consent in the Google UMP European message. Apple's ATT prompt is not shown. The recorder remains fully usable.
3. On the European consent path, ATT is considered only when the stored TCF choices affirmatively permit personalized advertising for Google.
4. If ATT is shown and the user selects Ask App Not to Track, the app remains fully usable and Google Mobile Ads does not receive IDFA or perform tracking.
5. Outside the European scope, ATT may be requested after the UMP privacy-status update when Apple's authorization status is still undetermined.
6. Settings > Privacy Options lets the user change applicable UMP choices when required. A privacy-options change is not immediately followed by ATT.

CHANGES IN BUILD 9

Build 9 contains the same tested GDPR-to-ATT correction as build 8 and uses the owner-approved white app icon. Core recording, StoreKit subscriptions, privacy links, and the no-account flow are unchanged.

Privacy Policy: https://krazel.github.io/audio-recorder/privacy/
Support: https://krazel.github.io/audio-recorder/support/
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`;
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
    headers: { Authorization: `Bearer ${token}`, ...(body ? { "Content-Type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : {};
  if (!response.ok) fail(`App Store Connect API failed ${method} ${endpoint}: ${response.status} ${text}`);
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

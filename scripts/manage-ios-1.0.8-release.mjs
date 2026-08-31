import crypto from "node:crypto";
import fs from "node:fs";

const appId = "6772278149";
const bundleId = "com.dmkr.audio.B2X6D3A9J9";
const marketingVersion = "1.0.8";
const buildNumber = "1";
const expectedLocales = new Set(["ca", "de-DE", "en-US", "es-ES", "fr-FR", "it", "pt-PT"]);
const expectedProductIds = new Set([
  "com.dmkr.audio.support.monthly.099",
  "com.dmkr.audio.support.monthly.299",
  "com.dmkr.audio.support.monthly.499",
  "com.dmkr.audio.support.monthly.999",
  "com.dmkr.audio.support.monthly.1499",
  "com.dmkr.audio.support.monthly.2999",
  "com.dmkr.audio.support.monthly.50"
]);
const operation = process.argv[2] ?? "status";
const validOperations = new Set(["status", "verify-unused", "finalize-production", "prepare", "submit"]);

if (!validOperations.has(operation)) {
  fail("Use status, verify-unused, finalize-production, prepare, or submit.");
}
if (operation === "prepare" && process.argv[3] !== "--confirm-prepare") {
  fail("Preparing App Store Connect requires --confirm-prepare.");
}
if (operation === "submit" && process.argv[3] !== "--confirm-submit") {
  fail("Submitting to App Review requires --confirm-submit.");
}

const token = createToken({
  keyId: requiredEnvironment("ASC_KEY_ID"),
  issuerId: requiredEnvironment("ASC_ISSUER_ID"),
  privateKey: fs.readFileSync(requiredEnvironment("ASC_PRIVATE_KEY_PATH"), "utf8")
});

const app = (await request("GET", `/v1/apps/${appId}`)).data;
if (app?.attributes?.bundleId !== bundleId) fail(`Unexpected app bundle ${app?.attributes?.bundleId ?? "missing"}.`);

if (operation === "verify-unused") {
  const build = await exactBuild({ required: false });
  if (build) fail(`${marketingVersion} (${buildNumber}) already exists as build ${build.id}.`);
  console.log(JSON.stringify({ status: "UNUSED", appId, bundleId, marketingVersion, buildNumber }, null, 2));
  process.exit(0);
}

if (operation === "status") {
  console.log(JSON.stringify(await snapshot(), null, 2));
  process.exit(0);
}

const build = await exactBuild({ required: true, wait: operation === "finalize-production" });
assertProductionBuild(build);

if (operation === "finalize-production") {
  console.log(JSON.stringify({ status: "PRODUCTION_BUILD_VALID", build: publicBuild(build) }, null, 2));
  process.exit(0);
}

if (operation === "prepare") {
  const version = await editableVersionForPreparation();
  if (version.attributes?.versionString !== marketingVersion) {
    await request("PATCH", `/v1/appStoreVersions/${version.id}`, {
      data: {
        type: "appStoreVersions",
        id: version.id,
        attributes: { versionString: marketingVersion }
      }
    });
  }

  await request("PATCH", `/v1/appStoreVersions/${version.id}`, {
    data: {
      type: "appStoreVersions",
      id: version.id,
      attributes: { releaseType: "MANUAL", usesIdfa: true }
    }
  });

  await updateVersionLocalizations(version.id);
  await request("PATCH", `/v1/appStoreVersions/${version.id}/relationships/build`, {
    data: { type: "builds", id: build.id }
  });

  const reviewDetail = (await request("GET", `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`)).data;
  if (!reviewDetail?.id) fail("App Review detail is missing.");
  const notes = reviewNotes();
  await request("PATCH", `/v1/appStoreReviewDetails/${reviewDetail.id}`, {
    data: { type: "appStoreReviewDetails", id: reviewDetail.id, attributes: { notes } }
  });

  const ready = await preflight(version.id, build.id);
  console.log(JSON.stringify({ status: "PREPARED_NOT_SUBMITTED", build: publicBuild(build), ...ready }, null, 2));
  process.exit(0);
}

const version = await exactAppStoreVersion();
const ready = await preflight(version.id, build.id);
const submissions = (await request("GET", `/v1/apps/${appId}/reviewSubmissions?limit=200`)).data ?? [];
const active = submissions.filter((item) => new Set(["READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW"]).has(item.attributes?.state));
let submission = null;

for (const candidate of active) {
  const details = await submissionSnapshot(candidate.id);
  if (details.items.some((item) => item.relatedId === version.id)) {
    submission = candidate;
    if (new Set(["WAITING_FOR_REVIEW", "IN_REVIEW"]).has(candidate.attributes?.state)) {
      console.log(JSON.stringify({ status: "ALREADY_SUBMITTED", submissionId: candidate.id, submissionState: candidate.attributes.state, ...ready }, null, 2));
      process.exit(0);
    }
    if (details.items.some((item) => item.relatedId !== version.id)) {
      fail(`Draft contains unexpected items: ${JSON.stringify(details.items)}.`);
    }
  } else if (candidate.attributes?.state === "READY_FOR_REVIEW") {
    const details = await submissionSnapshot(candidate.id);
    if (details.items.length !== 0) fail(`Another non-empty draft submission already exists: ${candidate.id}.`);
    submission = candidate;
  } else {
    fail(`Another active review submission exists: ${candidate.id} (${candidate.attributes?.state}).`);
  }
}

if (!submission) {
  submission = (await request("POST", "/v1/reviewSubmissions", {
    data: { type: "reviewSubmissions", relationships: { app: { data: { type: "apps", id: appId } } } }
  })).data;
}

let submissionDetails = await submissionSnapshot(submission.id);
if (!submissionDetails.items.some((item) => item.relatedId === version.id)) {
  await request("POST", "/v1/reviewSubmissionItems", {
    data: {
      type: "reviewSubmissionItems",
      relationships: {
        reviewSubmission: { data: { type: "reviewSubmissions", id: submission.id } },
        appStoreVersion: { data: { type: "appStoreVersions", id: version.id } }
      }
    }
  });
}

submissionDetails = await waitFor("review item readiness", async () => {
  const current = await submissionSnapshot(submission.id);
  return current.items.length === 1 && current.items[0].relatedId === version.id && current.items[0].itemState === "READY_FOR_REVIEW" ? current : false;
});

await request("PATCH", `/v1/reviewSubmissions/${submission.id}`, {
  data: { type: "reviewSubmissions", id: submission.id, attributes: { submitted: true } }
});

const submitted = await waitFor("App Review queue", async () => {
  const current = await submissionSnapshot(submission.id);
  return new Set(["WAITING_FOR_REVIEW", "IN_REVIEW"]).has(current.state) ? current : false;
});
const finalVersion = (await request("GET", `/v1/appStoreVersions/${version.id}?include=build`)).data;
if (finalVersion.attributes?.releaseType !== "MANUAL") fail("Release type changed after submission.");
if (finalVersion.relationships?.build?.data?.id !== build.id) fail("Selected build changed after submission.");

console.log(JSON.stringify({
  status: "SUBMITTED_FOR_REVIEW",
  submissionId: submission.id,
  submissionState: submitted.state,
  releaseType: finalVersion.attributes.releaseType,
  build: publicBuild(build),
  ...ready
}, null, 2));

async function snapshot() {
  const versions = (await request("GET", `/v1/apps/${appId}/appStoreVersions?filter[platform]=IOS&limit=200`)).data ?? [];
  const build = await exactBuild({ required: false });
  const groups = (await request("GET", `/v1/apps/${appId}/subscriptionGroups?limit=200`)).data ?? [];
  const subscriptions = groups.length === 1 ? await subscriptionSnapshot(groups[0].id) : [];
  const submissions = (await request("GET", `/v1/apps/${appId}/reviewSubmissions?limit=200`)).data ?? [];
  return {
    status: "CURRENT_STATE",
    appId,
    bundleId,
    marketingVersion,
    build: build ? publicBuild(build) : null,
    versions: await Promise.all(versions.map(async (version) => ({
      id: version.id,
      versionString: version.attributes?.versionString,
      state: version.attributes?.appVersionState,
      releaseType: version.attributes?.releaseType,
      usesIdfa: version.attributes?.usesIdfa,
      selectedBuildId: (await request("GET", `/v1/appStoreVersions/${version.id}/relationships/build`)).data?.id ?? null
    }))),
    submissions: submissions.map((item) => ({ id: item.id, state: item.attributes?.state })),
    subscriptionGroups: groups.map((item) => ({ id: item.id, referenceName: item.attributes?.referenceName, state: item.attributes?.state })),
    subscriptions
  };
}

async function editableVersionForPreparation() {
  const versions = (await request("GET", `/v1/apps/${appId}/appStoreVersions?filter[platform]=IOS&limit=200`)).data ?? [];
  const editable = versions.filter((item) => item.attributes?.appVersionState === "PREPARE_FOR_SUBMISSION");
  const exact = editable.filter((item) => item.attributes?.versionString === marketingVersion);
  if (exact.length === 1) return exact[0];
  if (exact.length > 1) fail(`Multiple editable ${marketingVersion} versions exist.`);
  if (editable.length !== 1 || editable[0].attributes?.versionString !== "1.0.3") {
    fail(`Expected one empty editable 1.0.3 train to rename; found ${JSON.stringify(editable.map((item) => ({ id: item.id, version: item.attributes?.versionString })))}.`);
  }
  const selected = (await request("GET", `/v1/appStoreVersions/${editable[0].id}/relationships/build`)).data;
  if (selected) fail("The 1.0.3 train unexpectedly has a selected build.");
  return editable[0];
}

async function exactAppStoreVersion() {
  const versions = (await request("GET", `/v1/apps/${appId}/appStoreVersions?filter[platform]=IOS&limit=200`)).data ?? [];
  const matches = versions.filter((item) => item.attributes?.versionString === marketingVersion);
  if (matches.length !== 1) fail(`Expected exactly one App Store version ${marketingVersion}; found ${matches.length}.`);
  return matches[0];
}

async function updateVersionLocalizations(versionId) {
  const values = (await request("GET", `/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations?limit=200`)).data ?? [];
  assertLocales(values);
  const whatsNew = releaseNotes();
  for (const value of values) {
    const locale = value.attributes?.locale;
    await request("PATCH", `/v1/appStoreVersionLocalizations/${value.id}`, {
      data: {
        type: "appStoreVersionLocalizations",
        id: value.id,
        attributes: {
          whatsNew: whatsNew[locale],
          marketingUrl: "https://krazel.github.io/audio-recorder/",
          supportUrl: "https://krazel.github.io/audio-recorder/support/"
        }
      }
    });
  }
}

async function preflight(versionId, expectedBuildId) {
  const version = (await request("GET", `/v1/appStoreVersions/${versionId}?include=build`)).data;
  if (version.attributes?.versionString !== marketingVersion) fail("Wrong marketing version selected.");
  if (version.attributes?.releaseType !== "MANUAL") fail("Release type must be MANUAL.");
  if (version.attributes?.usesIdfa !== true) fail("usesIdfa must be true for this AdMob/ATT build.");
  if (version.relationships?.build?.data?.id !== expectedBuildId) fail("The exact production build is not selected.");

  const localizations = (await request("GET", `/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations?limit=200`)).data ?? [];
  assertLocales(localizations);
  const screenshotCounts = {};
  for (const localization of localizations) {
    const locale = localization.attributes?.locale;
    if (localization.attributes?.supportUrl !== "https://krazel.github.io/audio-recorder/support/") fail(`Wrong support URL for ${locale}.`);
    if (localization.attributes?.marketingUrl !== "https://krazel.github.io/audio-recorder/") fail(`Wrong marketing URL for ${locale}.`);
    if (!localization.attributes?.whatsNew?.trim()) fail(`What's New is empty for ${locale}.`);
    const sets = (await request("GET", `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=200`)).data ?? [];
    let count = 0;
    for (const set of sets) {
      const screenshots = (await request("GET", `/v1/appScreenshotSets/${set.id}/appScreenshots?limit=200`)).data ?? [];
      count += screenshots.length;
    }
    if (count < 2) fail(`Expected at least two screenshots for ${locale}; found ${count}.`);
    screenshotCounts[locale] = count;
  }

  const reviewDetail = (await request("GET", `/v1/appStoreVersions/${versionId}/appStoreReviewDetail`)).data;
  if (!reviewDetail?.attributes?.notes?.includes("BUILD 1.0.8 (1)")) fail("Review Notes are not the exact 1.0.8 notes.");
  if (!reviewDetail.attributes?.contactPhone?.startsWith("+")) fail("App Review phone must use international format.");

  const groups = (await request("GET", `/v1/apps/${appId}/subscriptionGroups?limit=200`)).data ?? [];
  if (groups.length !== 1) fail(`Expected one subscription group; found ${groups.length}.`);
  const subscriptions = await subscriptionSnapshot(groups[0].id);
  const actualIds = new Set(subscriptions.map((item) => item.productId));
  if (actualIds.size !== expectedProductIds.size || [...expectedProductIds].some((id) => !actualIds.has(id))) {
    fail(`Subscription product set changed: ${JSON.stringify(subscriptions)}.`);
  }
  if (subscriptions.some((item) => item.state !== "APPROVED")) {
    fail(`Every existing subscription must remain APPROVED: ${JSON.stringify(subscriptions)}.`);
  }

  return {
    versionId,
    versionState: version.attributes?.appVersionState,
    releaseType: version.attributes.releaseType,
    usesIdfa: version.attributes.usesIdfa,
    selectedBuildId: version.relationships.build.data.id,
    locales: [...expectedLocales].sort(),
    screenshotCounts,
    subscriptions
  };
}

async function subscriptionSnapshot(groupId) {
  const values = (await request("GET", `/v1/subscriptionGroups/${groupId}/subscriptions?limit=200&fields[subscriptions]=productId,state,groupLevel,reviewNote`)).data ?? [];
  return values.map((item) => ({
    id: item.id,
    productId: item.attributes?.productId,
    state: item.attributes?.state,
    groupLevel: item.attributes?.groupLevel
  })).sort((a, b) => (a.productId ?? "").localeCompare(b.productId ?? ""));
}

async function exactBuild({ required, wait = false }) {
  const lookup = async () => {
    const prereleases = (await request("GET", `/v1/apps/${appId}/preReleaseVersions?limit=200`)).data ?? [];
    const releases = prereleases.filter((item) => item.attributes?.version === marketingVersion && item.attributes?.platform === "IOS");
    if (releases.length > 1) fail(`Multiple prerelease versions ${marketingVersion} exist.`);
    if (releases.length === 0) return null;
    const builds = (await request("GET", `/v1/preReleaseVersions/${releases[0].id}/builds?limit=200&fields[builds]=version,uploadedDate,expirationDate,expired,processingState,buildAudienceType,usesNonExemptEncryption`)).data ?? [];
    const matches = builds.filter((item) => item.attributes?.version === buildNumber);
    if (matches.length > 1) fail(`Multiple ${marketingVersion} (${buildNumber}) builds exist.`);
    return matches[0] ?? null;
  };
  let build = await lookup();
  if (wait && (!build || build.attributes?.processingState !== "VALID")) {
    build = await waitFor("production build processing", async () => {
      const value = await lookup();
      return value?.attributes?.processingState === "VALID" ? value : false;
    }, 90, 20_000);
  }
  if (required && !build) fail(`${marketingVersion} (${buildNumber}) does not exist.`);
  return build;
}

function assertProductionBuild(build) {
  if (build.attributes?.processingState !== "VALID") fail(`Build processing state is ${build.attributes?.processingState}.`);
  if (build.attributes?.buildAudienceType !== "APP_STORE_ELIGIBLE") fail(`Build audience is ${build.attributes?.buildAudienceType}.`);
  if (build.attributes?.expired === true) fail("Build is expired.");
  if (build.attributes?.usesNonExemptEncryption !== false) fail("usesNonExemptEncryption must be false.");
}

async function submissionSnapshot(submissionId) {
  const [submission, itemsResponse] = await Promise.all([
    request("GET", `/v1/reviewSubmissions/${submissionId}`),
    request("GET", `/v1/reviewSubmissions/${submissionId}/items?include=appStoreVersion,subscriptionVersion,subscriptionGroupVersion&limit=200`)
  ]);
  const relationshipNames = ["appStoreVersion", "subscriptionVersion", "subscriptionGroupVersion"];
  const items = (itemsResponse.data ?? []).map((item) => {
    const relationship = relationshipNames.map((name) => item.relationships?.[name]?.data).find(Boolean);
    return { id: item.id, itemState: item.attributes?.state, relatedId: relationship?.id ?? null, relatedType: relationship?.type ?? null };
  });
  return { state: submission.data.attributes?.state, items };
}

function assertLocales(values) {
  const actual = new Set(values.map((item) => item.attributes?.locale));
  if (actual.size !== expectedLocales.size || [...expectedLocales].some((locale) => !actual.has(locale))) {
    fail(`Expected exactly seven localizations; found ${JSON.stringify([...actual])}.`);
  }
}

function releaseNotes() {
  return {
    ca: "Millora la fiabilitat de les gravacions llargues i la recuperació després d’interrupcions. Reforça la protecció dels fitxers locals i elimina eines internes de diagnòstic.",
    "de-DE": "Verbessert die Zuverlässigkeit langer Aufnahmen und die Wiederaufnahme nach Unterbrechungen. Stärkt den Schutz lokaler Dateien und entfernt interne Diagnosewerkzeuge.",
    "en-US": "Improves long-recording reliability and recovery after interruptions. Strengthens local file protection and removes internal diagnostic tools.",
    "es-ES": "Mejora la fiabilidad de las grabaciones largas y la recuperación tras interrupciones. Refuerza la protección de los archivos locales y elimina herramientas internas de diagnóstico.",
    "fr-FR": "Améliore la fiabilité des enregistrements longs et la reprise après interruption. Renforce la protection des fichiers locaux et supprime les outils de diagnostic internes.",
    it: "Migliora l’affidabilità delle registrazioni lunghe e il ripristino dopo le interruzioni. Rafforza la protezione dei file locali e rimuove gli strumenti diagnostici interni.",
    "pt-PT": "Melhora a fiabilidade das gravações longas e a recuperação após interrupções. Reforça a proteção dos ficheiros locais e remove ferramentas internas de diagnóstico."
  };
}

function reviewNotes() {
  return `BUILD 1.0.8 (1)

PURPOSE AND AUDIENCE

Voice Recorder Pro - Audio K is an iPhone utility for recording voice notes, meetings, ideas, and everyday audio locally. No account or login is required.

CORE REVIEW FLOW

1. Launch the app and grant microphone access when recording is first requested.
2. Tap Record to start or stop. Recording mode, quality, file splitting, and sound sensitivity are in Settings; mode cannot be changed while recording.
3. Open Files to play, rename, favorite, delete, or manually share a recording.
4. Open Settings > Support the app to review optional monthly subscriptions, restore purchases, manage a subscription, and open Privacy Policy and Terms of Use.

SUBSCRIPTIONS

The optional auto-renewable monthly subscription removes ads while active. It does not unlock or block any recording feature. The seven displayed support prices provide the same ad-removal benefit. The USD 44.99 monthly price for Audio K Support Monthly 50 v2 is intentional. Purchases and restoration use Apple StoreKit.

PRIVACY, ADS, AND REGIONAL BEHAVIOR

The app uses Google UMP before any ad request and starts Google Mobile Ads only when canRequestAds is true. In the EEA/UK/Switzerland flow, choosing Do not consent does not trigger ATT. ATT is considered only when stored consent choices affirmatively permit personalized advertising for Google. Denying ATT leaves the recorder fully usable without IDFA tracking. Settings > Privacy Options lets users revisit applicable choices. Outside that scope, ATT may be requested after UMP finishes when authorization remains undetermined. Recording features are the same in all regions.

RECORDING RELIABILITY

This update improves long background recordings, continuous file rotation, recovery after Siri/audio interruptions when iOS permits execution, audio-stall detection, file protection after first unlock, and recovery of unindexed local segments before automatic restart. iOS can suspend a general recording app during an accepted phone call; the app preserves intent and retries as soon as iOS allows execution or the app returns to foreground.

DATA AND EXTERNAL SERVICES

Recordings remain on the device unless the user explicitly shares them with the iOS share sheet. The production app has no cloud uploader, server endpoint, account system, user-visible diagnostic export, or automatic diagnostic transmission. External services are Apple StoreKit and Google Mobile Ads/UMP.

Privacy Policy: https://krazel.github.io/audio-recorder/privacy/
Support: https://krazel.github.io/audio-recorder/support/
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`;
}

function publicBuild(value) {
  return {
    id: value.id,
    marketingVersion,
    buildNumber: value.attributes?.version,
    processingState: value.attributes?.processingState,
    buildAudienceType: value.attributes?.buildAudienceType,
    usesNonExemptEncryption: value.attributes?.usesNonExemptEncryption,
    expired: value.attributes?.expired,
    uploadedDate: value.attributes?.uploadedDate
  };
}

async function waitFor(label, check, attempts = 60, delayMs = 2_000) {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const value = await check();
    if (value) return value;
    await new Promise((resolve) => setTimeout(resolve, delayMs));
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

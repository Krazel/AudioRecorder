import crypto from "node:crypto";
import fs from "node:fs";

const appId = "6772278149";
const bundleId = "com.dmkr.audio.B2X6D3A9J9";
const marketingVersion = "1.0.3";
const buildNumber = "1";
const groupName = "Testers";
const marketingURL = "https://krazel.github.io/audio-recorder/";
const expectedLocalizationCount = 7;
const confirmation = process.argv[2];

if (confirmation !== "--confirm-internal-only-and-metadata") {
  fail("Explicit internal-testing and metadata confirmation is required.");
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

const versionQuery = new URLSearchParams({
  "filter[versionString]": marketingVersion,
  "filter[platform]": "IOS",
  limit: "10"
});
const versions = (
  await request("GET", `/v1/apps/${appId}/appStoreVersions?${versionQuery}`)
).data ?? [];
if (versions.length !== 1) {
  fail(`Expected one iOS App Store version ${marketingVersion}; found ${versions.length}.`);
}
const version = versions[0];
if (version.attributes?.releaseType !== "MANUAL") {
  fail(`Version ${marketingVersion} must keep manual release.`);
}

const localizationsResponse = await request(
  "GET",
  `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`
);
const localizations = localizationsResponse.data ?? [];
if (localizations.length !== expectedLocalizationCount) {
  fail(`Expected ${expectedLocalizationCount} localizations; found ${localizations.length}.`);
}
for (const localization of localizations) {
  if (localization.attributes?.marketingUrl === marketingURL) continue;
  await request("PATCH", `/v1/appStoreVersionLocalizations/${localization.id}`, {
    data: {
      type: "appStoreVersionLocalizations",
      id: localization.id,
      attributes: { marketingUrl: marketingURL }
    }
  });
}

const verifiedLocalizations = (
  await request("GET", `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`)
).data ?? [];
if (
  verifiedLocalizations.length !== expectedLocalizationCount ||
  verifiedLocalizations.some((item) => item.attributes?.marketingUrl !== marketingURL)
) {
  fail("The Marketing URL did not persist across all seven localizations.");
}

const preReleaseQuery = new URLSearchParams({
  "filter[version]": marketingVersion,
  "filter[platform]": "IOS",
  limit: "10"
});
const preReleaseVersions = (
  await request("GET", `/v1/apps/${appId}/preReleaseVersions?${preReleaseQuery}`)
).data ?? [];
if (preReleaseVersions.length !== 1) {
  fail(`Expected one prerelease version ${marketingVersion}; found ${preReleaseVersions.length}.`);
}

const build = await waitFor("processed TestFlight build", async () => {
  const builds = (
    await request(
      "GET",
      `/v1/preReleaseVersions/${preReleaseVersions[0].id}/builds?limit=200&fields[builds]=version,uploadedDate,expirationDate,expired,processingState,buildAudienceType,usesNonExemptEncryption`
    )
  ).data ?? [];
  const matching = builds.filter((candidate) => candidate.attributes?.version === buildNumber);
  if (matching.length > 1) fail(`Found multiple builds numbered ${buildNumber} in ${marketingVersion}.`);
  const candidate = matching[0];
  return candidate?.attributes?.processingState === "VALID" ? candidate : false;
});

if (build.attributes?.buildAudienceType !== "INTERNAL_ONLY") {
  fail(`Build audience is ${build.attributes?.buildAudienceType ?? "missing"}, not INTERNAL_ONLY.`);
}
if (build.attributes?.expired === true) fail("The TestFlight build is expired.");
if (build.attributes?.usesNonExemptEncryption !== false) {
  await request("PATCH", `/v1/builds/${build.id}`, {
    data: {
      type: "builds",
      id: build.id,
      attributes: { usesNonExemptEncryption: false }
    }
  });
}

const betaDetail = await waitFor("internal TestFlight availability", async () => {
  const detail = (await request("GET", `/v1/builds/${build.id}/buildBetaDetail`)).data;
  return new Set(["READY_FOR_BETA_TESTING", "IN_BETA_TESTING"]).has(
    detail?.attributes?.internalBuildState
  ) ? detail : false;
});

const groups = (await request("GET", `/v1/apps/${appId}/betaGroups?limit=200`)).data ?? [];
const matchingGroups = groups.filter((group) => group.attributes?.name === groupName);
if (matchingGroups.length !== 1) {
  fail(`Expected one beta group named ${groupName}; found ${matchingGroups.length}.`);
}
const group = matchingGroups[0];
if (group.attributes?.isInternalGroup !== true || group.attributes?.publicLinkEnabled === true) {
  fail(`Group ${groupName} is not private and internal.`);
}

const existingBuilds = (
  await request("GET", `/v1/betaGroups/${group.id}/relationships/builds?limit=200`)
).data ?? [];
const hasAccessToAllBuilds = group.attributes?.hasAccessToAllBuilds === true;
const alreadyLinked = existingBuilds.some((candidate) => candidate.id === build.id);
if (!hasAccessToAllBuilds && !alreadyLinked) {
  await request("POST", `/v1/betaGroups/${group.id}/relationships/builds`, {
    data: [{ type: "builds", id: build.id }]
  });
}

const linkedBuilds = (
  await request("GET", `/v1/betaGroups/${group.id}/relationships/builds?limit=200`)
).data ?? [];
const linked = linkedBuilds.some((candidate) => candidate.id === build.id);
if (!hasAccessToAllBuilds && !linked) fail("The build was not assigned to Testers.");

const testers = (
  await request("GET", `/v1/betaGroups/${group.id}/relationships/betaTesters?limit=200`)
).data ?? [];

console.log(JSON.stringify({
  status: hasAccessToAllBuilds ? "AVAILABLE_AUTOMATICALLY" : "ASSIGNED",
  appId,
  bundleId,
  appStoreVersionId: version.id,
  appStoreVersionState: version.attributes?.appVersionState,
  releaseType: version.attributes?.releaseType,
  usesIdfa: version.attributes?.usesIdfa,
  buildId: build.id,
  marketingVersion,
  buildNumber,
  processingState: build.attributes?.processingState,
  buildAudienceType: build.attributes?.buildAudienceType,
  usesNonExemptEncryption: false,
  uploadedDate: build.attributes?.uploadedDate,
  internalBuildState: betaDetail.attributes?.internalBuildState,
  externalBuildState: betaDetail.attributes?.externalBuildState,
  groupId: group.id,
  groupName,
  testerCount: testers.length,
  hasAccessToAllBuilds,
  linked,
  marketingURL,
  localizationCount: verifiedLocalizations.length,
  locales: verifiedLocalizations.map((item) => item.attributes?.locale).sort()
}, null, 2));

async function waitFor(label, check) {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const result = await check();
    if (result) return result;
    await new Promise((resolve) => setTimeout(resolve, 20_000));
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

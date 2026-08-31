import crypto from "node:crypto";
import fs from "node:fs";

const appId = "6772278149";
const bundleId = "com.dmkr.audio.B2X6D3A9J9";
const marketingVersion = "1.0.7";
const buildNumber = "1";
const groupName = "Testers";
const mode = process.argv[2];

if (!new Set(["--verify-unused", "--confirm-internal-only"]).has(mode)) {
  fail("Use --verify-unused or --confirm-internal-only.");
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

const prerelease = await findPrereleaseVersion();
const existingBuilds = prerelease
  ? await buildsForPrerelease(prerelease.id)
  : [];
const matchingBuilds = existingBuilds.filter(
  (candidate) => candidate.attributes?.version === buildNumber
);
if (matchingBuilds.length > 1) {
  fail(`Found multiple builds numbered ${buildNumber} in ${marketingVersion}.`);
}

if (mode === "--verify-unused") {
  if (matchingBuilds.length !== 0) {
    fail(`Version ${marketingVersion} build ${buildNumber} is already used.`);
  }
  console.log(JSON.stringify({
    status: "UNUSED",
    appId,
    bundleId,
    marketingVersion,
    buildNumber,
    prereleaseVersionExists: prerelease !== null
  }, null, 2));
  process.exit(0);
}

const build = await waitFor("processed TestFlight build", async () => {
  const candidatePrerelease = await findPrereleaseVersion();
  if (!candidatePrerelease) return false;
  const candidates = (await buildsForPrerelease(candidatePrerelease.id)).filter(
    (candidate) => candidate.attributes?.version === buildNumber
  );
  if (candidates.length > 1) {
    fail(`Found multiple builds numbered ${buildNumber} in ${marketingVersion}.`);
  }
  const candidate = candidates[0];
  return candidate?.attributes?.processingState === "VALID" ? candidate : false;
});

if (build.attributes?.buildAudienceType !== "INTERNAL_ONLY") {
  fail(`Build audience is ${build.attributes?.buildAudienceType ?? "missing"}, not INTERNAL_ONLY.`);
}
if (build.attributes?.expired === true) fail("The TestFlight build is expired.");
if (build.attributes?.usesNonExemptEncryption !== false) {
  fail("The build does not declare usesNonExemptEncryption=false.");
}

const betaDetail = await waitFor("internal TestFlight availability", async () => {
  const detail = (await request("GET", `/v1/builds/${build.id}/buildBetaDetail`)).data;
  return detail?.attributes?.internalBuildState === "IN_BETA_TESTING" ? detail : false;
});
if (betaDetail.attributes?.externalBuildState !== "NOT_APPLICABLE") {
  fail(`External build state is ${betaDetail.attributes?.externalBuildState ?? "missing"}, not NOT_APPLICABLE.`);
}

const group = await waitFor("private automatic Testers group", async () => {
  const groups = (await request("GET", `/v1/apps/${appId}/betaGroups?limit=200`)).data ?? [];
  const matchingGroups = groups.filter((candidate) => candidate.attributes?.name === groupName);
  if (matchingGroups.length !== 1) {
    fail(`Expected one beta group named ${groupName}; found ${matchingGroups.length}.`);
  }
  const candidate = matchingGroups[0];
  if (candidate.attributes?.isInternalGroup !== true || candidate.attributes?.publicLinkEnabled === true) {
    fail(`Group ${groupName} is not private and internal.`);
  }
  return candidate.attributes?.hasAccessToAllBuilds === true ? candidate : false;
});

const linked = await waitFor("automatic Testers build relationship", async () => {
  const relationships = (
    await request("GET", `/v1/betaGroups/${group.id}/relationships/builds?limit=200`)
  ).data ?? [];
  return relationships.some((candidate) => candidate.id === build.id);
});

const testers = (
  await request("GET", `/v1/betaGroups/${group.id}/relationships/betaTesters?limit=200`)
).data ?? [];
if (testers.length !== 2) {
  fail(`Expected exactly two internal testers; found ${testers.length}.`);
}

const selectedByVersions = await appStoreVersionsSelecting(build.id);
if (selectedByVersions.length !== 0) {
  fail(`Internal build is selected by App Store version(s): ${selectedByVersions.join(", ")}.`);
}

console.log(JSON.stringify({
  status: "AVAILABLE_AUTOMATICALLY",
  appId,
  bundleId,
  buildId: build.id,
  marketingVersion,
  buildNumber,
  processingState: build.attributes?.processingState,
  buildAudienceType: build.attributes?.buildAudienceType,
  usesNonExemptEncryption: build.attributes?.usesNonExemptEncryption,
  uploadedDate: build.attributes?.uploadedDate,
  internalBuildState: betaDetail.attributes?.internalBuildState,
  externalBuildState: betaDetail.attributes?.externalBuildState,
  groupId: group.id,
  groupName,
  testerCount: testers.length,
  hasAccessToAllBuilds: group.attributes?.hasAccessToAllBuilds,
  linked,
  selectedByAppStoreVersions: selectedByVersions
}, null, 2));

async function findPrereleaseVersion() {
  const values = (
    await request("GET", `/v1/apps/${appId}/preReleaseVersions?limit=200`)
  ).data ?? [];
  const matches = values.filter((candidate) =>
    candidate.attributes?.version === marketingVersion &&
    candidate.attributes?.platform === "IOS"
  );
  if (matches.length > 1) {
    fail(`Expected at most one prerelease version ${marketingVersion}; found ${matches.length}.`);
  }
  return matches[0] ?? null;
}

async function buildsForPrerelease(prereleaseId) {
  return (
    await request(
      "GET",
      `/v1/preReleaseVersions/${prereleaseId}/builds?limit=200&fields[builds]=version,uploadedDate,expirationDate,expired,processingState,buildAudienceType,usesNonExemptEncryption`
    )
  ).data ?? [];
}

async function appStoreVersionsSelecting(buildId) {
  const versions = (
    await request("GET", `/v1/apps/${appId}/appStoreVersions?limit=200`)
  ).data ?? [];
  const selected = [];
  for (const version of versions) {
    const relationship = await request(
      "GET",
      `/v1/appStoreVersions/${version.id}/relationships/build`
    );
    if (relationship.data?.id === buildId) {
      selected.push(version.attributes?.versionString ?? version.id);
    }
  }
  return selected;
}

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

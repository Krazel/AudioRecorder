import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const bundleIdentifier = process.env.IOS_BUNDLE_IDENTIFIER ?? "com.dmkr.audio.B2X6D3A9J9";
const profileName = process.env.IOS_PROFILE_NAME ?? "VoiceRecorder App Store 2026-08-08";
if (process.argv[2] !== "--confirm-create-voice-recorder-signing") {
  fail("Creation requires --confirm-create-voice-recorder-signing.");
}
const csrPath = requiredArgument(3, "CSR path");
const outputDirectory = requiredArgument(4, "output directory");
const statePath = path.join(outputDirectory, "signing-resource-state.json");

const keyId = requiredEnvironment("ASC_KEY_ID");
const issuerId = requiredEnvironment("ASC_ISSUER_ID");
const privateKeyPath = requiredEnvironment("ASC_PRIVATE_KEY_PATH");
const privateKey = fs.readFileSync(privateKeyPath, "utf8");
const csrContent = fs.readFileSync(csrPath, "utf8").trim();

fs.mkdirSync(outputDirectory, { recursive: true });
const state = readState();
const token = createAppStoreConnectToken({ keyId, issuerId, privateKey });

const bundleIds = await ascRequest(token, "GET", "/v1/bundleIds?limit=200");
const bundleId = bundleIds.data?.find((candidate) => candidate.attributes?.identifier === bundleIdentifier);
if (!bundleId || bundleId.attributes?.identifier !== bundleIdentifier) {
  fail(`No exact Bundle ID resource exists for ${bundleIdentifier}.`);
}
const bundleProfiles = await ascRequest(token, "GET", `/v1/bundleIds/${bundleId.id}/profiles?limit=200`);
const conflictingProfile = bundleProfiles.data?.find((profile) =>
  profile.attributes?.name === profileName && profile.attributes?.profileState === "ACTIVE"
);
if (!state.profileId && conflictingProfile) {
  fail(`An active profile named ${profileName} already exists (${conflictingProfile.id}); refusing to create a duplicate.`);
}

let certificateId = state.certificateId;
if (!certificateId) {
  const certificate = await ascRequest(token, "POST", "/v1/certificates", {
    data: {
      type: "certificates",
      attributes: {
        certificateType: "DISTRIBUTION",
        csrContent
      }
    }
  });
  certificateId = certificate.data.id;
  const certificateContent = certificate.data.attributes?.certificateContent;
  if (!certificateContent) fail("Apple created the certificate without downloadable content.");
  fs.writeFileSync(path.join(outputDirectory, "VoiceRecorder-Distribution.cer"), Buffer.from(certificateContent, "base64"));
  Object.assign(state, {
    bundleId: bundleId.id,
    bundleIdentifier,
    certificateId,
    certificateType: certificate.data.attributes?.certificateType,
    certificateExpirationDate: certificate.data.attributes?.expirationDate
  });
  writeState();
  console.log(`Created Apple distribution certificate: ${certificateId}`);
} else {
  console.log(`Reusing certificate recorded in local state: ${certificateId}`);
}

let profileId = state.profileId;
if (!profileId) {
  const profile = await ascRequest(token, "POST", "/v1/profiles", {
    data: {
      type: "profiles",
      attributes: {
        name: profileName,
        profileType: "IOS_APP_STORE"
      },
      relationships: {
        bundleId: {
          data: { type: "bundleIds", id: bundleId.id }
        },
        certificates: {
          data: [{ type: "certificates", id: certificateId }]
        }
      }
    }
  });
  profileId = profile.data.id;
  const profileContent = profile.data.attributes?.profileContent;
  if (!profileContent) fail("Apple created the profile without downloadable content.");
  fs.writeFileSync(path.join(outputDirectory, "VoiceRecorder-App-Store.mobileprovision"), Buffer.from(profileContent, "base64"));
  Object.assign(state, {
    profileId,
    profileName: profile.data.attributes?.name,
    profileType: profile.data.attributes?.profileType,
    profileUuid: profile.data.attributes?.uuid,
    profileExpirationDate: profile.data.attributes?.expirationDate
  });
  writeState();
  console.log(`Created App Store profile: ${profileId}`);
} else {
  console.log(`Reusing profile recorded in local state: ${profileId}`);
}

console.log(`Signing resources ready for ${bundleIdentifier}.`);

async function ascRequest(tokenValue, method, endpoint, body) {
  const response = await fetch(`https://api.appstoreconnect.apple.com${endpoint}`, {
    method,
    headers: {
      Authorization: `Bearer ${tokenValue}`,
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

function readState() {
  if (!fs.existsSync(statePath)) return {};
  return JSON.parse(fs.readFileSync(statePath, "utf8"));
}

function writeState() {
  fs.writeFileSync(statePath, `${JSON.stringify(state, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
}

function createAppStoreConnectToken({ keyId: tokenKeyId, issuerId: tokenIssuerId, privateKey: tokenPrivateKey }) {
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
  const signature = signer.sign({ key: tokenPrivateKey, dsaEncoding: "ieee-p1363" });
  return `${input}.${base64url(signature)}`;
}

function base64url(value) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value);
  return buffer.toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function requiredArgument(index, label) {
  const value = process.argv[index];
  if (!value) fail(`Missing ${label}. Usage: node scripts/create-apple-signing-resources.mjs --confirm-create-voice-recorder-signing <csr-path> <output-directory>`);
  return path.resolve(value);
}

function requiredEnvironment(name) {
  const value = process.env[name];
  if (!value) fail(`Missing ${name}.`);
  return value;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

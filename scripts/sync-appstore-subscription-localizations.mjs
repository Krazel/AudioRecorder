import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const manifestPath = process.argv[2];
const shouldApply = process.argv.includes("--apply");

if (!manifestPath) {
  fail("Usage: node scripts/sync-appstore-subscription-localizations.mjs <store-manifest.json> [--apply]");
}

const manifest = JSON.parse(fs.readFileSync(path.resolve(manifestPath), "utf8"));
const bundleId = manifest.app?.iosBundleId;
const config = manifest.ios?.subscriptions;
if (!bundleId || !config?.groupReferenceName || !Array.isArray(config.products)) {
  fail("The manifest must define app.iosBundleId and ios.subscriptions.");
}

const token = createToken({
  keyId: requiredEnv("ASC_KEY_ID"),
  issuerId: requiredEnv("ASC_ISSUER_ID"),
  privateKey: fs.readFileSync(requiredEnv("ASC_PRIVATE_KEY_PATH"), "utf8")
});

const app = first(await get(`/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`), `app ${bundleId}`);
const groups = await get(`/v1/apps/${app.id}/subscriptionGroups?limit=200`);
const group = (groups.data ?? []).find((item) => item.attributes?.referenceName === config.groupReferenceName);
if (!group) fail(`Subscription group not found: ${config.groupReferenceName}`);

const subscriptions = await get(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=200`);
const byProductId = new Map((subscriptions.data ?? []).map((item) => [item.attributes?.productId, item]));
let changes = 0;

for (const product of config.products) {
  const subscription = byProductId.get(product.productId);
  if (!subscription) fail(`Subscription not found: ${product.productId}`);

  const localizations = await get(`/v1/subscriptions/${subscription.id}/subscriptionLocalizations?limit=200`);
  const byLocale = new Map((localizations.data ?? []).map((item) => [item.attributes?.locale, item]));

  for (const [locale, desired] of Object.entries(product.locales ?? {})) {
    const existing = byLocale.get(locale);
    const attributes = { name: desired.displayName, description: desired.description };
    const alreadyMatches = existing &&
      existing.attributes?.name === attributes.name &&
      existing.attributes?.description === attributes.description;

    if (alreadyMatches) {
      console.log(`OK ${product.productId} ${locale}`);
      continue;
    }

    changes += 1;
    if (!shouldApply) {
      console.log(`WOULD UPDATE ${product.productId} ${locale}: ${attributes.name}`);
      continue;
    }

    if (existing) {
      await request("PATCH", `/v1/subscriptionLocalizations/${existing.id}`, {
        data: { type: "subscriptionLocalizations", id: existing.id, attributes }
      });
    } else {
      await request("POST", "/v1/subscriptionLocalizations", {
        data: {
          type: "subscriptionLocalizations",
          attributes: { locale, ...attributes },
          relationships: { subscription: { data: { type: "subscriptions", id: subscription.id } } }
        }
      });
    }
    console.log(`UPDATED ${product.productId} ${locale}: ${attributes.name}`);
  }
}

console.log(shouldApply ? `Applied ${changes} localization changes.` : `Dry run: ${changes} localization changes pending.`);

async function get(endpoint) {
  return request("GET", endpoint);
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
  if (!response.ok) fail(`App Store Connect ${method} ${endpoint} failed: ${response.status} ${text}`);
  return json;
}

function first(response, label) {
  const value = response.data?.[0];
  if (!value) fail(`Could not find ${label}.`);
  return value;
}

function createToken({ keyId, issuerId, privateKey }) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" }));
  const payload = base64url(JSON.stringify({
    iss: issuerId,
    aud: "appstoreconnect-v1",
    exp: now + 19 * 60,
    iat: now
  }));
  const input = `${header}.${payload}`;
  const signer = crypto.createSign("SHA256");
  signer.update(input);
  signer.end();
  return `${input}.${base64url(signer.sign({ key: privateKey, dsaEncoding: "ieee-p1363" }))}`;
}

function base64url(value) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value);
  return buffer.toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) fail(`Missing environment variable: ${name}`);
  return value;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

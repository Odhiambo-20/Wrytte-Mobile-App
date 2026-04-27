import { setGlobalOptions } from "firebase-functions";
import { onRequest } from "firebase-functions/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// ── Secrets ────────────────────────────────────────────────────────────────
const openimAdminSecret  = defineSecret("OPENIM_ADMIN_SECRET");
const openimApiUrl       = defineSecret("OPENIM_API_URL");
const twilioSid          = defineSecret("TWILIO_ACCOUNT_SID");
const twilioToken        = defineSecret("TWILIO_AUTH_TOKEN");
const twilioVerifySid    = defineSecret("TWILIO_VERIFY_SERVICE_SID");

// ── Global options ─────────────────────────────────────────────────────────
setGlobalOptions({ maxInstances: 10 });

// ── Firebase Admin ─────────────────────────────────────────────────────────
admin.initializeApp();

// ── Helpers ────────────────────────────────────────────────────────────────

/** Parse x-www-form-urlencoded or JSON body from an onRequest call */
function parseBody(req: any): Record<string, string> {
  const ct = (req.headers["content-type"] || "").toLowerCase();
  if (ct.includes("application/json")) return req.body ?? {};
  if (ct.includes("application/x-www-form-urlencoded")) return req.body ?? {};
  // multipart fields are also parsed by Firebase into req.body
  return req.body ?? {};
}

/** Get an admin token from OpenIM */
async function getOpenImAdminToken(): Promise<string> {
  const url    = `${openimApiUrl.value()}/auth/user_token`;
  const secret = openimAdminSecret.value();

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      secret,
      platformID: 1,
      userID: "imAdmin",
    }),
  });

  const data: any = await res.json();
  if (!res.ok || data.errCode !== 0) {
    throw new Error(`OpenIM admin token error: ${JSON.stringify(data)}`);
  }
  return data.data.token;
}

/**
 * Register or get a user in OpenIM.
 * Returns { userid, username, secret, token }
 */
async function openImRegisterOrLogin(params: {
  userID: string;
  nickname: string;
  phone: string;
}): Promise<{ userid: string; username: string; secret: string; token: string; expiresAt: string }> {
  const adminToken = await getOpenImAdminToken();
  const baseUrl    = openimApiUrl.value();
  const appSecret  = openimAdminSecret.value();

  // Try to get user token first (login path)
  const tokenRes = await fetch(`${baseUrl}/auth/user_token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "operationID": Date.now().toString(),
      "token": adminToken,
    },
    body: JSON.stringify({
      secret: appSecret,
      platformID: 1,
      userID: params.userID,
    }),
  });

  const tokenData: any = await tokenRes.json();

  // If user already exists, return their token
  if (tokenRes.ok && tokenData.errCode === 0) {
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    return {
      userid:    params.userID,
      username:  params.nickname,
      secret:    appSecret,
      token:     tokenData.data.token,
      expiresAt,
    };
  }

  // User doesn't exist — register them
  const regRes = await fetch(`${baseUrl}/user/user_register`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "operationID": Date.now().toString(),
      "token": adminToken,
    },
    body: JSON.stringify({
      secret: appSecret,
      users: [{
        userID:   params.userID,
        nickname: params.nickname,
        faceURL:  "",
      }],
    }),
  });

  const regData: any = await regRes.json();
  if (!regRes.ok || regData.errCode !== 0) {
    throw new Error(`OpenIM register error: ${JSON.stringify(regData)}`);
  }

  // Now get user token after registration
  const tokenRes2 = await fetch(`${baseUrl}/auth/user_token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "operationID": Date.now().toString(),
      "token": adminToken,
    },
    body: JSON.stringify({
      secret: appSecret,
      platformID: 1,
      userID: params.userID,
    }),
  });

  const tokenData2: any = await tokenRes2.json();
  if (!tokenRes2.ok || tokenData2.errCode !== 0) {
    throw new Error(`OpenIM token after register error: ${JSON.stringify(tokenData2)}`);
  }

  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  return {
    userid:    params.userID,
    username:  params.nickname,
    secret:    appSecret,
    token:     tokenData2.data.token,
    expiresAt,
  };
}

/** Derive a stable OpenIM userID from a phone number */
function phoneToUserId(phone: string): string {
  // Strip non-digits, prefix with "ph_" to keep it stable and unique
  return "ph_" + phone.replace(/\D/g, "");
}

// ── CORS helper ────────────────────────────────────────────────────────────
function setCors(res: any) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

// ══════════════════════════════════════════════════════════════════════════
// ROUTE 1 — POST /auth/register/sendsmscode
// Flutter calls this from RealNumberService.sendSmsCode()
// Body: { phone: "+2547XXXXXXXX" }
// ══════════════════════════════════════════════════════════════════════════
export const sendsmscode = onRequest(
  {
    secrets: [twilioSid, twilioToken, twilioVerifySid],
  },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }
    if (req.method !== "POST")    { res.status(405).send("Method Not Allowed"); return; }

    const { phone } = parseBody(req);

    if (!phone) {
      res.status(400).json({ error: "phone is required" });
      return;
    }

    try {
      logger.info("Sending SMS OTP to", phone);

      const twilioClient = require("twilio")(
        twilioSid.value(),
        twilioToken.value()
      );

      await twilioClient.verify.v2
        .services(twilioVerifySid.value())
        .verifications.create({ to: phone, channel: "sms" });

      logger.info("OTP sent to", phone);
      res.status(200).json({ success: true });
    } catch (err: any) {
      logger.error("sendsmscode error", err);
      res.status(500).json({ error: err.message ?? "Failed to send SMS" });
    }
  }
);

// ══════════════════════════════════════════════════════════════════════════
// ROUTE 2 — POST /auth/register/rpn  (register/verify real phone number)
// Flutter calls this from AuthService.registerRealPhone()
// Body: { phone, code, username?, login }
// Returns: { userid, username, secret, token, expiresAt }
// ══════════════════════════════════════════════════════════════════════════
export const rpn = onRequest(
  {
    secrets: [twilioSid, twilioToken, twilioVerifySid, openimAdminSecret, openimApiUrl],
  },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }
    if (req.method !== "POST")    { res.status(405).send("Method Not Allowed"); return; }

    const body     = parseBody(req);
    const phone    = body.phone;
    const code     = body.code;
    const username = body.username ?? "";

    if (!phone || !code) {
      res.status(400).json({ error: "phone and code are required" });
      return;
    }

    try {
      // Step 1 — Verify the OTP with Twilio
      logger.info("Verifying OTP for", phone);

      const twilioClient = require("twilio")(
        twilioSid.value(),
        twilioToken.value()
      );

      const check = await twilioClient.verify.v2
        .services(twilioVerifySid.value())
        .verificationChecks.create({ to: phone, code });

      if (check.status !== "approved") {
        res.status(401).json({ error: "Invalid or expired verification code" });
        return;
      }

      logger.info("OTP approved for", phone);

      // Step 2 — Register or login the user in OpenIM
      const userID   = phoneToUserId(phone);
      const nickname = username || `user_${userID.slice(-6)}`;

      const openimUser = await openImRegisterOrLogin({
        userID,
        nickname,
        phone,
      });

      // Step 3 — Store phone → userID mapping in Firestore for future logins
      await admin.firestore().collection("users").doc(userID).set({
        phone,
        username: openimUser.username,
        userId:   userID,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      logger.info("rpn complete for", phone, "->", userID);
      res.status(200).json(openimUser);
    } catch (err: any) {
      logger.error("rpn error", err);
      res.status(500).json({ error: err.message ?? "Registration failed" });
    }
  }
);

// ══════════════════════════════════════════════════════════════════════════
// ROUTE 3 — POST /auth/login
// Flutter calls this from AuthService.login()
// Body: { secret, userid?, phone?, username? }
// Returns: { userid, username, secret, token, expiresAt }
// ══════════════════════════════════════════════════════════════════════════
export const login = onRequest(
  {
    secrets: [openimAdminSecret, openimApiUrl],
  },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }
    if (req.method !== "POST")    { res.status(405).send("Method Not Allowed"); return; }

    const body   = parseBody(req);
    const secret = body.secret;
    const userid = body.userid;
    const phone  = body.phone;

    if (!secret) {
      res.status(400).json({ error: "secret is required" });
      return;
    }

    // Validate secret matches our app secret
    if (secret !== openimAdminSecret.value()) {
      res.status(401).json({ error: "Invalid secret" });
      return;
    }

    try {
      // Resolve userID — from body directly or look up by phone
      let resolvedUserId = userid;

      if (!resolvedUserId && phone) {
        resolvedUserId = phoneToUserId(phone);
      }

      if (!resolvedUserId) {
        res.status(400).json({ error: "userid or phone is required" });
        return;
      }

      logger.info("Login for userID", resolvedUserId);

      // Get a fresh OpenIM token
      const adminToken = await getOpenImAdminToken();
      const baseUrl    = openimApiUrl.value();

      const tokenRes = await fetch(`${baseUrl}/auth/user_token`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "operationID": Date.now().toString(),
          "token": adminToken,
        },
        body: JSON.stringify({
          secret: openimAdminSecret.value(),
          platformID: 1,
          userID: resolvedUserId,
        }),
      });

      const tokenData: any = await tokenRes.json();

      if (!tokenRes.ok || tokenData.errCode !== 0) {
        res.status(401).json({ error: "User not found or login failed" });
        return;
      }

      // Fetch username from Firestore
      const userDoc  = await admin.firestore().collection("users").doc(resolvedUserId).get();
      const username = userDoc.exists ? (userDoc.data()?.username ?? "") : "";
      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

      logger.info("Login success for", resolvedUserId);

      res.status(200).json({
        userid:    resolvedUserId,
        username,
        secret:    openimAdminSecret.value(),
        token:     tokenData.data.token,
        expiresAt,
      });
    } catch (err: any) {
      logger.error("login error", err);
      res.status(500).json({ error: err.message ?? "Login failed" });
    }
  }
);

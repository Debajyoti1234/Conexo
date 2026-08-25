import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FCM_SERVICE_ACCOUNT_JSON =
  Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";

serve(async (req) => {
  try {
    const body = await req.json();
    const eventType = body.event_type as string | undefined;
    const recipientId = body.recipient_id as string | undefined;
    const actorId = body.actor_id as string | undefined;
    const title = body.title as string | undefined;
    const bodyText = body.body as string | undefined;
    const entityId = body.entity_id as string | undefined;
    const entityType = body.entity_type as string | undefined;

    if (!eventType || !recipientId || !title || !bodyText) {
      return json(
        { error: "event_type, recipient_id, title, and body are required" },
        400,
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: devices, error: devicesError } = await supabase
      .from("user_devices")
      .select("push_token, platform")
      .eq("user_id", recipientId);

    if (devicesError || !devices || devices.length === 0) {
      return json({ ok: true, reason: "no_device_tokens" });
    }

    const tokens: string[] = [];
    for (const d of devices) {
      const token = d.push_token as string;
      if (token && token.trim().length > 0) {
        tokens.push(token);
      }
    }

    if (tokens.length === 0) {
      return json({ ok: true, reason: "no_valid_tokens" });
    }

    let sentCount = 0;
    let fcmErrors: string[] = [];
    let fcmProjectId = "";

    if (FCM_SERVICE_ACCOUNT_JSON) {
      const result = await sendFcm(tokens, title, bodyText, eventType, entityId, entityType);
      sentCount = result.sent;
      fcmErrors = result.errors;
      fcmProjectId = result.projectId;
    }

    return json({
      ok: true,
      sent: sentCount,
      recipients: 1,
      tokens: tokens.length,
      service_account_present: !!FCM_SERVICE_ACCOUNT_JSON,
      fcm_project_id: fcmProjectId,
      fcm_errors: fcmErrors,
    });
  } catch (error) {
    console.error("notify-event error:", error);
    return json({ ok: false, error: "internal_error" }, 500);
  }
});

async function sendFcm(
  tokens: string[],
  title: string,
  body: string,
  eventType: string,
  entityId: string | undefined,
  entityType: string | undefined,
): Promise<{ sent: number; errors: string[]; projectId: string }> {
  const sa = JSON.parse(FCM_SERVICE_ACCOUNT_JSON);
  const projectId = sa.project_id;
  const errors: string[] = [];
  let accessToken = "";

  try {
    accessToken = await getAccessToken(sa);
  } catch (e) {
    errors.push(`access_token_error: ${String(e)}`);
    return { sent: 0, errors, projectId };
  }

  const data: Record<string, string> = {
    type: eventType,
    title,
    body,
  };
  if (entityId) data.entity_id = entityId;
  if (entityType) data.entity_type = entityType;

  let sent = 0;
  for (const token of tokens) {
    const fcmMessage = {
      message: {
        token,
        notification: {
          title,
          body,
        },
        data,
        android: {
          priority: "high",
          notification: {
            channel_id: "conexo_messages",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      },
    };

    try {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(fcmMessage),
        },
      );
      if (res.ok) {
        sent++;
      } else {
        const errBody = await res.text();
        console.error("FCM send failed:", res.status, errBody);
        errors.push(`status_${res.status}: ${errBody.slice(0, 300)}`);
      }
    } catch (e) {
      console.error("FCM send exception:", e);
      errors.push(`exception: ${String(e).slice(0, 200)}`);
    }
  }
  return { sent, errors, projectId };
}

async function getAccessToken(sa: Record<string, unknown>): Promise<string> {
  const header = b64url(
    JSON.stringify({ alg: "RS256", typ: "JWT" }),
  );
  const now = Math.floor(Date.now() / 1000);
  const claim = b64url(
    JSON.stringify({
      iss: (sa as Record<string, string>).client_email,
      sub: (sa as Record<string, string>).client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const signingInput = `${header}.${claim}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer((sa as Record<string, string>).private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );

  const jwt = `${signingInput}.${b64urlBytes(new Uint8Array(signature))}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body:
      `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  const tokenJson = await tokenRes.json();
  return tokenJson.access_token;
}

function b64url(input: string): string {
  return btoa(input).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=/g,
    "",
  );
}

function b64urlBytes(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return b64url(binary);
}

function pemToDer(pem: string): Uint8Array {
  const b64 = pem.replace(/-----BEGIN PRIVATE KEY-----/, "").replace(
    /-----END PRIVATE KEY-----/,
    "",
  ).replace(/\s+/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

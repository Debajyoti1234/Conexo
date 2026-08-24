import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FCM_SERVICE_ACCOUNT_JSON =
  Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";

serve(async (req) => {
  try {
    const { message_id } = await req.json();
    if (!message_id) {
      return json({ error: "message_id is required" }, 400);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: message, error: messageError } = await supabase
      .from("messages")
      .select("id, conversation_id, sender_id, type, content, created_at, deleted_at")
      .eq("id", message_id)
      .single();

    if (messageError || !message) {
      return json({ ok: false, reason: "message_not_found" }, 404);
    }

    if (message.type === "system" || message.deleted_at !== null) {
      return json({ ok: true, reason: "ignored" });
    }

    const { data: conversation, error: convError } = await supabase
      .from("conversations")
      .select("id, type, plan_id")
      .eq("id", message.conversation_id)
      .single();

    if (convError || !conversation) {
      return json({ ok: false, reason: "conversation_not_found" }, 200);
    }

    const { data: members, error: membersError } = await supabase
      .from("conversation_members")
      .select("user_id, last_notified_at")
      .eq("conversation_id", conversation.id)
      .neq("user_id", message.sender_id);

    if (membersError || !members || members.length === 0) {
      return json({ ok: true, reason: "no_recipients" });
    }

    const recipientIds: string[] = [];
    for (const m of members) {
      const lastNotified = m.last_notified_at as string | null;
      if (lastNotified && lastNotified >= message.created_at) {
        continue;
      }
      recipientIds.push(m.user_id as string);
    }

    if (recipientIds.length === 0) {
      return json({ ok: true, reason: "all_already_notified" });
    }

    const { data: mutes } = await supabase
      .from("conversation_mutes")
      .select("user_id")
      .eq("conversation_id", conversation.id)
      .in("user_id", recipientIds);

    const mutedUserIds = new Set<string>();
    for (const m of mutes ?? []) {
      mutedUserIds.add(m.user_id as string);
    }

    const eligibleUserIds: string[] = [];
    for (const uid of recipientIds) {
      if (mutedUserIds.has(uid)) continue;
      eligibleUserIds.push(uid);
    }

    if (conversation.type === "connection") {
      const { data: blocks } = await supabase
        .from("blocks")
        .select("blocker_id, blocked_id")
        .or(
          `and(blocker_id.eq.${message.sender_id},blocked_id.in.(${csv(eligibleUserIds)})),and(blocked_id.eq.${message.sender_id},blocker_id.in.(${csv(
            eligibleUserIds,
          )}))`,
        );

      const blockedUserIds = new Set<string>();
      for (const b of blocks ?? []) {
        if (b.blocker_id === message.sender_id) {
          blockedUserIds.add(b.blocked_id as string);
        }
        if (b.blocked_id === message.sender_id) {
          blockedUserIds.add(b.blocker_id as string);
        }
      }

      const filtered: string[] = [];
      for (const uid of eligibleUserIds) {
        if (!blockedUserIds.has(uid)) filtered.push(uid);
      }
      eligibleUserIds.splice(0, eligibleUserIds.length, ...filtered);
    }

    if (eligibleUserIds.length === 0) {
      return json({ ok: true, reason: "no_eligible_recipients" });
    }

    let title = "Conexo";
    let body = "You have a new message";
    let planId: string | null = null;

    // The sender's real display name is resolved for BOTH chat types and placed
    // INSIDE the notification sentence — never as the title. The title always
    // stays "Conexo" so the notification reads as one cohesive Conexo message.
    // Recipient eligibility (mute / block / dedup / deleted) is resolved above
    // and is intentionally left unchanged.
    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("display_name")
      .eq("id", message.sender_id)
      .single();
    const senderName = (senderProfile?.display_name as string | undefined) ??
      "Someone";

    if (conversation.type === "connection") {
      title = "Conexo";
      body = `You have a new message from ${senderName}`;
    } else {
      planId = conversation.plan_id as string | null;
      let planTitle = "your plan";
      if (planId) {
        const { data: plan } = await supabase
          .from("plans")
          .select("title")
          .eq("id", planId)
          .single();
        planTitle = (plan?.title as string | undefined) ?? "your plan";
      }
      title = "Conexo";
      body = `"${planTitle}" — ${senderName} replied`;
    }

    const { data: devices, error: devicesError } = await supabase
      .from("user_devices")
      .select("push_token")
      .in("user_id", eligibleUserIds);

    if (devicesError || !devices || devices.length === 0) {
      return json({ ok: true, reason: "no_device_tokens" });
    }

    const tokens: string[] = [];
    for (const d of devices) {
      tokens.push(d.push_token as string);
    }

    let sentCount = 0;
    let fcmErrors: string[] = [];
    let fcmProjectId = "";
    if (FCM_SERVICE_ACCOUNT_JSON) {
      const result = await sendFcm(
        tokens,
        title,
        body,
        conversation.type,
        conversation.id,
        planId,
      );
      sentCount = result.sent;
      fcmErrors = result.errors;
      fcmProjectId = result.projectId;
    }

    const now = new Date().toISOString();
    for (const uid of eligibleUserIds) {
      await supabase
        .from("conversation_members")
        .update({ last_notified_at: now })
        .eq("conversation_id", conversation.id)
        .eq("user_id", uid);
    }

    return json({
      ok: true,
      sent: sentCount,
      recipients: eligibleUserIds.length,
      tokens: tokens.length,
      service_account_present: !!FCM_SERVICE_ACCOUNT_JSON,
      fcm_project_id: fcmProjectId,
      fcm_errors: fcmErrors,
    });
  } catch (error) {
    console.error("notify-chat-message error:", error);
    return json({ ok: false, error: "internal_error" }, 500);
  }
});

function csv(ids: string[]): string {
  return ids.map((id) => `"${id}"`).join(",");
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function sendFcm(
  tokens: string[],
  title: string,
  body: string,
  convType: string,
  conversationId: string,
  planId: string | null,
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
    type: convType === "plan" ? "plan_message" : "connection_message",
    conversation_id: conversationId,
    title,
    body,
  };
  if (planId) data.plan_id = planId;

  let sent = 0;
  for (const token of tokens) {
    // NOTIFICATION + DATA transport (P5.2 proven-working baseline). The
    // `notification` block lets Android render the notification itself while the
    // app is backgrounded/terminated, so delivery does NOT depend on a custom
    // native service or the Dart background isolate. The `data` block is kept
    // for tap routing (type/conversation_id/plan_id) and the foreground path,
    // which renders exactly one local notification. `android.priority: high`
    // keeps delivery prompt and `channel_id` targets the existing
    // high-importance `conexo_messages` channel. Exactly one notification per
    // state: foreground -> local (onMessage); background/terminated -> system
    // (notification block); never both.
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

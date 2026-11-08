// CycleSync: send-reminders Edge Function.
//
// GET  -> returns the public web-push key the app needs to subscribe.
// POST -> sends every reminder that is due (called every 5 minutes by pg_cron).
//
// Deploy with "Verify JWT" OFF. Both actions are safe without a login:
// GET only returns a public key, and POST only sends reminders that users
// scheduled for themselves, once each.

import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const CONTACT = "mailto:cyclesync-push@users.noreply.github.com";
const LATE_LIMIT_MS = 12 * 60 * 60 * 1000; // skip reminders more than 12h late

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

/** Loads the web-push keys, creating them the first time. */
async function vapidKeys(): Promise<{ publicKey: string; privateKey: string }> {
  const { data } = await db
    .from("push_config")
    .select("public_key, private_key")
    .eq("id", 1)
    .maybeSingle();
  if (data) return { publicKey: data.public_key, privateKey: data.private_key };

  const keys = webpush.generateVAPIDKeys();
  await db.from("push_config").upsert(
    { id: 1, public_key: keys.publicKey, private_key: keys.privateKey },
    { onConflict: "id", ignoreDuplicates: true },
  );
  // Re-read in case another run created them at the same time.
  const { data: again } = await db
    .from("push_config")
    .select("public_key, private_key")
    .eq("id", 1)
    .single();
  return { publicKey: again!.public_key, privateKey: again!.private_key };
}

async function sendDue(): Promise<{ sent: number; skipped: number }> {
  const keys = await vapidKeys();
  webpush.setVapidDetails(CONTACT, keys.publicKey, keys.privateKey);

  const now = Date.now();
  const { data: due, error } = await db
    .from("scheduled_pushes")
    .select("id, user_id, kind, send_at, title, body, repeats_daily")
    .lte("send_at", new Date(now).toISOString())
    .order("send_at")
    .limit(500);
  if (error) throw error;

  let sent = 0;
  let skipped = 0;
  for (const r of due ?? []) {
    const late = now - new Date(r.send_at).getTime() > LATE_LIMIT_MS;
    if (!late) {
      const { data: subs } = await db
        .from("push_subscriptions")
        .select("id, endpoint, p256dh, auth")
        .eq("user_id", r.user_id);
      for (const s of subs ?? []) {
        try {
          await webpush.sendNotification(
            { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
            JSON.stringify({ title: r.title, body: r.body, tag: r.kind }),
            { TTL: 6 * 60 * 60 },
          );
          sent++;
        } catch (e) {
          const code = (e as { statusCode?: number }).statusCode;
          if (code === 404 || code === 410) {
            // The browser unsubscribed; forget it.
            await db.from("push_subscriptions").delete().eq("id", s.id);
          }
        }
      }
    } else {
      skipped++;
    }

    if (r.repeats_daily) {
      // Move to the next future occurrence.
      let next = new Date(r.send_at).getTime();
      while (next <= now) next += 24 * 60 * 60 * 1000;
      await db
        .from("scheduled_pushes")
        .update({ send_at: new Date(next).toISOString() })
        .eq("id", r.id);
    } else {
      await db.from("scheduled_pushes").delete().eq("id", r.id);
    }
  }
  return { sent, skipped };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    if (req.method === "GET") {
      const { publicKey } = await vapidKeys();
      return json({ publicKey });
    }
    if (req.method === "POST") {
      return json(await sendDue());
    }
    return json({ error: "method_not_allowed" }, 405);
  } catch (_e) {
    // No details: errors could include personal data.
    return json({ error: "server_error" }, 500);
  }
});

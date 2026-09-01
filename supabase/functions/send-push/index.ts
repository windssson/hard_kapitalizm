import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts";

interface FirebaseServiceAccount {
  project_id: string;
  private_key: string;
  client_email: string;
}

// Get Google OAuth2 token using the service account JSON
async function getAccessToken(serviceAccount: FirebaseServiceAccount): Promise<string> {
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const rawKey = serviceAccount.private_key
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s+/g, "");

  const binaryKey = Uint8Array.from(atob(rawKey), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: getNumericDate(60 * 60), // 1 hour
    iat: getNumericDate(0),
  };

  const jwt = await create({ alg: "RS256", typ: "JWT" }, payload, cryptoKey);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Failed to obtain Google access token: ${JSON.stringify(data)}`);
  }

  return data.access_token;
}

serve(async (req) => {
  try {
    const { token, title, message, player_id } = await req.json();

    if (!token || !title || !message) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Load Firebase Service Account from Environment Secrets
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      return new Response(JSON.stringify({ error: "FIREBASE_SERVICE_ACCOUNT secret not configured in Supabase Secrets." }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const serviceAccount: FirebaseServiceAccount = JSON.parse(serviceAccountJson);
    const projectId = serviceAccount.project_id;

    // Get OAuth2 Access Token
    const accessToken = await getAccessToken(serviceAccount);

    // Call FCM v1 API
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    const fcmBody = {
      message: {
        token: token,
        notification: {
          title: title,
          body: message,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          player_id: player_id || "",
        },
        android: {
          priority: "HIGH",
          notification: {
            channel_id: "fcm_fallback_notification_channel",
            icon: "ic_launcher",
            default_sound: true,
            default_vibrate_timings: true,
            notification_priority: "PRIORITY_HIGH",
            visibility: "PUBLIC",
          },
        },
      },
    };

    const fcmResponse = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(fcmBody),
    });

    const fcmData = await fcmResponse.json();

    if (!fcmResponse.ok) {
      // ----------------------------------------------------
      // Clean up invalid or unregistered push tokens from the database
      // ----------------------------------------------------
      const errorMsg = fcmData.error?.message || "";
      if (
        fcmResponse.status === 404 ||
        fcmResponse.status === 410 ||
        errorMsg.includes("Requested entity was not found") ||
        errorMsg.includes("unregistered")
      ) {
        const supabaseUrl = Deno.env.get("SUPABASE_URL");
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
        if (supabaseUrl && supabaseServiceKey) {
          try {
            await fetch(`${supabaseUrl}/rest/v1/player_push_tokens?token=eq.${encodeURIComponent(token)}`, {
              method: "DELETE",
              headers: {
                "apikey": supabaseServiceKey,
                "Authorization": `Bearer ${supabaseServiceKey}`,
                "Content-Type": "application/json"
              }
            });
            console.log(`Deleted invalid push token from database: ${token}`);
          } catch (dbErr) {
            console.error(`Failed to delete invalid token from database: ${dbErr.message}`);
          }
        }
      }

      return new Response(JSON.stringify({ error: "FCM delivery failed", details: fcmData }), {
        status: fcmResponse.status,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true, message_id: fcmData.name }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

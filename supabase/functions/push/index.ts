import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.23.0";
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts';

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

/**
 * Strips PEM headers/footers and extra whitespace to extract the raw base64 key.
 */
function sanitizePrivateKey(pem: string) {
    let body = pem
        .replace(/-----BEGIN PRIVATE KEY-----/g, '')
        .replace(/-----END PRIVATE KEY-----/g, '');

    const matched = body.match(/[A-Za-z0-9+/=_]+/g);
    if (!matched) return "";
    return matched.join('').replace(/-/g, '+').replace(/_/g, '/');
}

/**
 * Imports a PKCS8 private key for RS256 signing.
 */
async function importKey(pem: string): Promise<CryptoKey> {
    const cleanBase64 = sanitizePrivateKey(pem);
    if (!cleanBase64) throw new Error("Invalid private key format.");

    let binaryStr;
    try {
        binaryStr = atob(cleanBase64);
    } catch (e) {
        // Handle potential base64 padding issues
        const padded = cleanBase64.padEnd(cleanBase64.length + (4 - cleanBase64.length % 4) % 4, '=');
        binaryStr = atob(padded);
    }

    const der = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) der[i] = binaryStr.charCodeAt(i);
    return crypto.subtle.importKey(
        "pkcs8",
        der,
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"]
    );
}

/**
 * Exchanges a Service Account JWT for a Google OAuth2 Access Token.
 */
async function getAccessToken(serviceAccount: any) {
    const key = await importKey(serviceAccount.private_key);
    const now = Math.floor(Date.now() / 1000);

    // Construct JWT for Google OAuth2
    const jwt = await new jose.SignJWT({
        iss: serviceAccount.client_email,
        sub: serviceAccount.client_email,
        aud: "https://oauth2.googleapis.com/token",
        scope: "https://www.googleapis.com/auth/firebase.messaging https://www.googleapis.com/auth/cloud-platform",
        iat: now - 60,
        exp: now + 3600,
    }).setProtectedHeader({
        alg: 'RS256',
        typ: 'JWT',
        kid: serviceAccount.private_key_id
    }).sign(key);

    const res = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
            grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
            assertion: jwt
        }),
    });

    if (!res.ok) {
        const errData = await res.json();
        throw new Error(`Cloud Auth Failed: ${JSON.stringify(errData)}`);
    }
    const data = await res.json();
    return data.access_token;
}

serve(async (req) => {
    // 1. Handle CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        // 2. Validate Request
        if (req.method !== 'POST') {
            return new Response("Method not allowed", { status: 405, headers: corsHeaders });
        }

        const payload = await req.json();
        let targetUserId = payload.user_id;

        // Support database webhooks which pass the record in 'record'
        if (payload.record) targetUserId = payload.record.user_id;

        if (!targetUserId) {
            return new Response("Missing target user_id", { status: 400, headers: corsHeaders });
        }

        // 3. Initialize Supabase Client
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
        const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
        const supabase = createClient(supabaseUrl, supabaseKey);

        // 4. Fetch FCM Token
        const { data: profile, error: dbError } = await supabase
            .from("profiles")
            .select("fcm_token")
            .eq("user_id", targetUserId)
            .single();

        if (dbError || !profile?.fcm_token) {
            console.log(`Push skipped: No FCM token for user ${targetUserId}`);
            return new Response(JSON.stringify({ success: false, message: "No FCM token" }), {
                status: 200,
                headers: { ...corsHeaders, "Content-Type": "application/json" }
            });
        }

        // 5. Authenticate with Firebase
        const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
        if (!serviceAccountJson) {
            throw new Error("FIREBASE_SERVICE_ACCOUNT environment variable is not set.");
        }
        const serviceAccount = JSON.parse(serviceAccountJson);
        const accessToken = await getAccessToken(serviceAccount);

        // 6. Build FCM Message
        const url = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

        // Extract content from payload
        const title = payload.title || "New Notification";
        const body = payload.body || "Tap to view details";
        const data = payload.data || {};

        const messagePayload = {
            message: {
                token: profile.fcm_token.trim(),
                notification: {
                    title: title,
                    body: body,
                },
                data: {
                    ...data,
                    click_action: "FLUTTER_NOTIFICATION_CLICK"
                },
                android: {
                    priority: "high",
                    notification: {
                        sound: "default",
                        click_action: "FLUTTER_NOTIFICATION_CLICK"
                    }
                },
                apns: {
                    headers: {
                        "apns-push-type": "alert",
                        "apns-topic": "com.nerdherd.app"
                    },
                    payload: {
                        aps: {
                            alert: {
                                title: title,
                                body: body
                            },
                            sound: "default",
                            badge: 1,
                        }
                    }
                }
            }
        };

        // 7. Send Request
        const response = await fetch(url, {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${accessToken}`,
                "Content-Type": "application/json"
            },
            body: JSON.stringify(messagePayload),
        });

        const resultText = await response.text();
        const fcmStatus = response.status;

        if (fcmStatus === 200) {
            console.log(`Push sent successfully to user ${targetUserId}`);
        } else {
            console.error(`FCM Delivery Failed (${fcmStatus}):`, resultText);
        }

        return new Response(resultText, {
            status: fcmStatus,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
        });

    } catch (error) {
        console.error("Internal Push Error:", error.message);
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: corsHeaders
        });
    }
});

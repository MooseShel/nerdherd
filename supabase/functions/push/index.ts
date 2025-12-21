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
    if (!pem) return "";

    // 1. Try to extract strictly between headers first (handles multiline /s)
    const headerRegex = /-----BEGIN[^-]*-----(.*)-----END[^-]*-----/s;
    const match = pem.match(headerRegex);
    let body = match ? match[1] : pem;

    // 2. Remove all non-base64 characters
    // We only keep A-Z, a-z, 0-9, +, /, =, -, _
    let cleanBase64 = body.replace(/[^A-Za-z0-9+/=\-_]/g, '');

    // 3. Robust header/footer stripping (in case regex failed or headers were mangled)
    const keywords = ["BEGIN", "PRIVATE", "KEY", "END"];
    keywords.forEach(word => {
        if (cleanBase64.startsWith(word)) cleanBase64 = cleanBase64.substring(word.length);
        if (cleanBase64.endsWith(word)) cleanBase64 = cleanBase64.substring(0, cleanBase64.length - word.length);
    });

    // 4. Normalize base64url to standard base64
    return cleanBase64.replace(/-/g, '+').replace(/_/g, '/');
}

/**
 * Robust JSON parser that handles potential unquoted keys or formatting issues
 * from environment variables.
 */
function safeJsonParse(text: string, sourceName: string) {
    console.log(`safeJsonParse: Parsing ${sourceName} (length: ${text?.length ?? 0}). Starts with: ${text?.substring(0, 40)}...`);
    try {
        return JSON.parse(text);
    } catch {
        try {
            const fixed = text
                .replace(/([{,])\s*([a-z0-9A-Z_]+)\s*:/g, '$1"$2":')
                .replace(/:\s*([^"{\[][^,}\s]+)/g, ':"$1"');
            return JSON.parse(fixed);
        } catch (e: any) {
            // Last resort: Extract fields with regex if the whole JSON is mangled
            const extract = (key: string) => {
                // This regex is now "greedier" and allows spaces/newlines until a comma/brace
                const match = text.match(new RegExp(`"${key}"\\s*:\\s*"([^"]+)"`)) ||
                    text.match(new RegExp(`'${key}'\\s*:\\s*'([^']+)'`)) ||
                    text.match(new RegExp(`${key}\\s*:\\s*([^",}]+)`));
                return match ? match[1].trim() : undefined;
            };

            if (sourceName === "FIREBASE_SERVICE_ACCOUNT") {
                const extracted = {
                    project_id: extract("project_id"),
                    client_email: extract("client_email"),
                    private_key: extract("private_key")?.replace(/\\n/g, '\n'),
                    private_key_id: extract("private_key_id")
                };
                if (extracted.private_key && extracted.client_email) {
                    console.log(`safeJsonParse: Fallback extracted email: ${extracted.client_email}, key length: ${extracted.private_key.length}`);
                    return extracted;
                }
            }
            throw new Error(`${sourceName} is not valid JSON.`);
        }
    }
}

/**
 * Imports a PKCS8 private key for RS256 signing.
 */
async function importKey(pem: string): Promise<CryptoKey> {
    console.log(`importKey: Received PEM of length ${pem?.length ?? 0}. Starts with: ${pem?.substring(0, 30)}...`);
    const cleanBase64 = sanitizePrivateKey(pem);
    if (!cleanBase64) {
        throw new Error(`Invalid private key format. (Received length: ${pem?.length ?? 0})`);
    }

    let binaryStr;
    try {
        console.log(`importKey: Decoding base64 (length: ${cleanBase64.length}, starts with: ${cleanBase64.substring(0, 20)}...)`);
        binaryStr = atob(cleanBase64);
    } catch (e: any) {
        console.warn("importKey: atob failed on cleanBase64, trying padding...");
        try {
            const padded = cleanBase64.padEnd(cleanBase64.length + (4 - cleanBase64.length % 4) % 4, '=');
            binaryStr = atob(padded);
        } catch (e2: any) {
            console.error("importKey: atob failed even with padding. First 50 chars:", cleanBase64.substring(0, 50));
            throw new Error(`Failed to decode base64: ${e2.message}`);
        }
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
    if (!serviceAccount.client_email) {
        throw new Error("Service Account JSON is missing 'client_email'");
    }

    console.log(`Getting access token for: ${serviceAccount.client_email}`);
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

serve(async (req: Request) => {
    // 1. Handle CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        // 2. Validate Request
        if (req.method !== 'POST') {
            return new Response("Method not allowed", { status: 405, headers: corsHeaders });
        }

        let payload;
        const bodyText = await req.text();
        try {
            payload = JSON.parse(bodyText);
        } catch (e: any) {
            console.error("Failed to parse request body:", bodyText);
            return new Response(JSON.stringify({ error: "Invalid JSON in request body", details: e.message }), {
                status: 400,
                headers: { ...corsHeaders, "Content-Type": "application/json" }
            });
        }

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

        const serviceAccount = safeJsonParse(serviceAccountJson, "FIREBASE_SERVICE_ACCOUNT");
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

    } catch (error: any) {
        console.error("Internal Push Error:", error.message);
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: corsHeaders
        });
    }
});

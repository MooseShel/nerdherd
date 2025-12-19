// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This function needs a FIREBASE_SERVICE_ACCOUNT secret set in Supabase Dashboard.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.23.0";

// JWT for Google OAuth2 (Manual implementation to avoid large admin SDK in edge) or use a lightweight lib
// Actually, it's easier to use the FCM HTTP v1 API with a service account.
// For simplicity in this generated code, we'll assume we can use a helper or simple fetch with service account.
// NOTE: Proper FCM V1 requires signing a JWT with the service account private key. 
// We will use a simplified implementation that expects the user to handle the JWT signing or use a library that supports it.
// To ensure checking, we will use 'firebase-admin' via CDN if compat, or just raw HTTP with a provided token logic.

// BUT, for Deno Edge Functions, 'npm:firebase-admin' is supported!
// BUT, for Deno Edge Functions, 'npm:firebase-admin' is supported!
import admin from "npm:firebase-admin@11.11.0";

// Initialize Firebase Admin
// Note: In production, it's safer to pass service account via Environment Variable string and parse it.
// Here we assume the user might upload the json or stringify it.
// Let's retry with the ENV Variable approach which is standard.

console.log("Hello from Push Function!");

serve(async (req) => {
    try {
        const payload = await req.json();

        // If payload has 'record', it's likely a DB webhook.
        // If it has direct keys, it's direct invoke.
        // If payload has 'record', it's likely a DB webhook.
        // If it has direct keys, it's direct invoke.

        let targetUserId = payload.user_id;
        let title = payload.title;
        let body = payload.body;
        let data = payload.data || {};

        // If record exists (DB Webhook from 'notifications' table)
        if (payload.record) {
            targetUserId = payload.record.user_id;
            title = payload.record.title;
            body = payload.record.body;
            data = payload.record.data || {};
            // mapping 'type' to data
            if (payload.record.type) data.type = payload.record.type;
        }

        if (!targetUserId) {
            return new Response("Missing user_id", { status: 400 });
        }

        // Initialize Supabase to fetch token
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
        const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
        const supabase = createClient(supabaseUrl, supabaseKey);

        // Fetch FCM Token
        const { data: profile, error } = await supabase
            .from("profiles")
            .select("fcm_token")
            .eq("user_id", targetUserId)
            .single();

        if (error || !profile?.fcm_token) {
            console.log(`No FCM token for user ${targetUserId}`);
            return new Response("No FCM token found", { status: 200 });
        }

        // Init Admin SDK if not already
        // We need the service account from Env Var
        if (admin.apps.length === 0) {
            const serviceAccountStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
            if (!serviceAccountStr) {
                throw new Error("Missing FIREBASE_SERVICE_ACCOUNT env var");
            }
            const serviceAccount = JSON.parse(serviceAccountStr);

            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
            });
        }

        // Send Message
        const message = {
            token: profile.fcm_token,
            notification: {
                title: title,
                body: body,
            },
            data: data, // data must be map of string:string
            android: {
                priority: 'high',
                notification: {
                    sound: 'default'
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default'
                    }
                }
            }
        };

        // Convert data values to strings (FCM requirement)
        for (const key in message.data) {
            if (typeof message.data[key] !== 'string') {
                message.data[key] = String(message.data[key]);
            }
        }

        const response = await admin.messaging().send(message);
        console.log("Successfully sent message:", response);

        return new Response(JSON.stringify({ success: true, messageId: response }), {
            headers: { "Content-Type": "application/json" },
        });

    } catch (error) {
        console.error("Error sending push:", error);
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { "Content-Type": "application/json" },
        });
    }
});

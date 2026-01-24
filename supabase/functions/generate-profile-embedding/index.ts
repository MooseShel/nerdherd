import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.23.0";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
        const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
        const geminiApiKey = Deno.env.get("GEMINI_API_KEY");

        if (!geminiApiKey) {
            throw new Error("GEMINI_API_KEY not set");
        }

        const { record } = await req.json();
        const userId = record.user_id;
        const bio = record.bio || "";
        const classes = (record.current_classes || []).join(", ");

        const inputText = `Bio: ${bio}\nClasses: ${classes}`;

        if (!bio && !classes) {
            return new Response(JSON.stringify({ message: "No content to embed" }), {
                status: 200,
                headers: { ...corsHeaders, "Content-Type": "application/json" }
            });
        }

        // Generate embedding using Gemini
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${geminiApiKey}`;

        const geminiRes = await fetch(geminiUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                model: "models/text-embedding-004",
                content: { parts: [{ text: inputText }] }
            })
        });

        if (!geminiRes.ok) {
            const err = await geminiRes.json();
            throw new Error(`Gemini API Error: ${JSON.stringify(err)}`);
        }

        const geminiData = await geminiRes.json();
        const embedding = geminiData.embedding.values;

        // Update profile with embedding
        const supabase = createClient(supabaseUrl, supabaseKey);
        const { error: updateError } = await supabase
            .from("profiles")
            .update({ bio_embedding: embedding })
            .eq("user_id", userId);

        if (updateError) throw updateError;

        return new Response(JSON.stringify({ success: true }), {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
        });

    } catch (error: any) {
        console.error("Embedding Error:", error.message);
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
    }
});

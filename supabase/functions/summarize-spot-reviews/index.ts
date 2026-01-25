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
        const spotId = record.spot_id;

        if (!spotId) {
            return new Response("Missing spot_id", { status: 400 });
        }

        const supabase = createClient(supabaseUrl, supabaseKey);

        // Fetch latest 10 reviews for the spot
        const { data: reviews, error: fetchError } = await supabase
            .from("spot_reviews")
            .select("comment, rating")
            .eq("spot_id", spotId)
            .order("created_at", { ascending: false })
            .limit(10);

        if (fetchError) throw fetchError;

        if (!reviews || reviews.length === 0) {
            return new Response(JSON.stringify({ message: "No reviews to summarize" }), {
                status: 200,
                headers: { ...corsHeaders, "Content-Type": "application/json" }
            });
        }

        const reviewText = reviews.map(r => `[Rating: ${r.rating}/5] ${r.comment}`).join("\n");

        const prompt = `
    Analyze these user reviews for a study spot and provide:
    1. A one-sentence 'Vibe Summary' that captures the essence of the environment.
    2. A list of 3-5 short 'AI Tags' (e.g., "Fast Wi-Fi", "Quiet", "Crowded").
    3. A 'Noise Level' from 1 to 5 (1: Silent, 2: Quiet, 3: Moderate, 4: Loud, 5: Very Loud).

    Format the response as JSON:
    {
      "vibe_summary": "string",
      "ai_tags": ["tag1", "tag2", "tag3"],
      "noise_level": number
    }

    Reviews:
    ${reviewText}
    `;

        // Call Gemini API - Use v1beta with gemini-2.5-flash-lite (User specified)
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${geminiApiKey}`;

        const geminiRes = await fetch(geminiUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                contents: [{ parts: [{ text: `${prompt}\n\u003cIMPORTANT\u003e Ensure your entire response is a single valid JSON object. Do not include markdown formatting or backticks. \u003c/IMPORTANT\u003e` }] }],
            })
        });

        if (!geminiRes.ok) {
            const err = await geminiRes.text();
            throw new Error(`Gemini API Error: ${err}`);
        }

        const geminiData = await geminiRes.json();
        let text = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;

        if (!text) {
            throw new Error("Empty response from Gemini");
        }

        // --- ROBUST PARSING ---
        // 1. Remove markdown backticks if present
        text = text.replace(/```json/g, "").replace(/```/g, "").trim();

        let aiOutput;
        try {
            aiOutput = JSON.parse(text);
        } catch (e) {
            console.error("Failed to parse AI response as JSON:", text);
            // Fallback: Try to extract JSON between { and }
            const match = text.match(/\{[\s\S]*\}/);
            if (match) {
                aiOutput = JSON.parse(match[0]);
            } else {
                throw new Error("AI response is not valid JSON and couldn't be cleaned.");
            }
        }

        // Update study spot with AI insights
        const { error: updateError } = await supabase
            .from("study_spots")
            .update({
                vibe_summary: aiOutput.vibe_summary,
                ai_tags: aiOutput.ai_tags,
                noise_level: aiOutput.noise_level
            })
            .eq("id", spotId);

        if (updateError) throw updateError;

        return new Response(JSON.stringify({ success: true, ...aiOutput }), {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
        });

    } catch (error: any) {
        console.error("Summarization Error:", error.message);
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
    }
});

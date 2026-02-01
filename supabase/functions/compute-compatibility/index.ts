import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const _supabaseUrl = Deno.env.get('SUPABASE_URL')!
const _supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(_supabaseUrl, _supabaseServiceRoleKey)

serve(async (req) => {
  try {
    console.log("🌌 Compute Compatibility: Starting run...")

    // 1. Fetch Users with Classes
    // We get a lighter payload: ID, Courses, Role
    const { data: users, error: userError } = await supabase
      .from('profiles')
      .select('user_id, current_classes, is_tutor, intent_tag')
      .not('current_classes', 'is', null)
    // Optimization: Only users active in last 30 days?
    // For MVP, we do all.

    if (userError) throw userError
    if (!users || users.length < 2) {
      console.log("Not enough users to compute compatibility.")
      return new Response(JSON.stringify({ success: true, matches: 0 }))
    }

    console.log(`Analyzing ${users.length} users for constellations...`)

    let updateCount = 0
    const upserts = []

    // 2. Simple N^2 Loop (or Blocked Loop)
    // For < 1000 users, N^2 is fine (~1M ops, fast in memory).
    for (let i = 0; i < users.length; i++) {
      for (let j = i + 1; j < users.length; j++) {
        const u1 = users[i]
        const u2 = users[j]

        // SCORING LOGIC
        let score = 0.0
        const factors = {
          course_overlap: 0,
          role_complement: 0,
          intent_match: 0
        }

        // A. Course Overlap (Weights: 0.3 per shared course, max 0.6)
        if (u1.current_classes && u2.current_classes) {
          const c1 = u1.current_classes as string[]
          const c2 = u2.current_classes as string[]
          const intersection = c1.filter(c => c2.includes(c))

          if (intersection.length > 0) {
            factors.course_overlap = Math.min(intersection.length * 0.3, 0.6)
            score += factors.course_overlap
          }
        }

        // B. Role Complementarity (Weight: 0.2)
        // Tutor + Student = Good match if they share a subject (implied by overlap or general domain)
        // Here we just check binary roles
        if (u1.is_tutor !== u2.is_tutor) {
          factors.role_complement = 0.2
          score += factors.role_complement
        }

        // C. Intent Match (Weight: 0.1)
        if (u1.intent_tag && u2.intent_tag && u1.intent_tag === u2.intent_tag) {
          factors.intent_match = 0.1
          score += factors.intent_match
        }

        // D. Threshold
        // Only save if score > 0.3 (some meaningful connection)
        if (score > 0.3) {
          upserts.push({
            user_a: u1.user_id,
            user_b: u2.user_id,
            score: Math.min(score, 1.0), // Cap at 1.0
            factors,
            last_updated: new Date()
          })
          // Also add reverse? The table PK is (user_a, user_b), constraint likely requires a < b or specific order
          // Let's assume the table handles one-way or we normalize IDs.
          // Best practice: Store lowest ID in user_a
        }
      }
    }

    // 3. Batch Upsert
    // Normalize IDs to prevent duplicates (user_a < user_b)
    const normalizedUpserts = upserts.map(r => {
      if (r.user_a < r.user_b) return r;
      return { ...r, user_a: r.user_b, user_b: r.user_a }
    })

    if (normalizedUpserts.length > 0) {
      // Chunking for Supabase limit (approx 1000 rows per insert)
      const chunkSize = 1000
      for (let k = 0; k < normalizedUpserts.length; k += chunkSize) {
        const chunk = normalizedUpserts.slice(k, k + chunkSize)
        const { error: batchError } = await supabase
          .from('compatibility_scores')
          .upsert(chunk, { onConflict: 'user_a,user_b' })

        if (batchError) console.error("Batch upsert error:", batchError)
        else updateCount += chunk.length
      }
    }

    console.log(`✅ Computed ${updateCount} compatibility scores.`)

    return new Response(
      JSON.stringify({ success: true, updates: updateCount }),
      { headers: { "Content-Type": "application/json" } },
    )
  } catch (error) {
    console.error("❌ Critical Error:", error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }
})

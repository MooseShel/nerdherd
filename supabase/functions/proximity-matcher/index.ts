import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const _supabaseUrl = Deno.env.get('SUPABASE_URL')!
const _supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(_supabaseUrl, _supabaseServiceRoleKey)

serve(async (req) => {
  try {
    console.log("🔍 Proximity Matcher: Starting run...")

    // 1. Get all Active Struggle Signals
    const { data: activeSignals, error: signalError } = await supabase
      .from('struggle_signals')
      .select(`
        id,
        user_id,
        location,
        subject,
        topic,
        confidence_level,
        profiles (
          id,
          full_name,
          intent_tag,
          serendipity_radius_meters
        )
      `)
      .eq('is_active', true)
      .gt('expires_at', new Date().toISOString())

    if (signalError) throw signalError
    if (!activeSignals || activeSignals.length === 0) {
      console.log("✅ No active signals found. Exiting.")
      return new Response(JSON.stringify({ success: true, count: 0 }), { headers: { 'Content-Type': 'application/json' } })
    }

    console.log(`📡 Found ${activeSignals.length} active signals.`)

    let matchCount = 0

    // 2. For each signal, find nearby potential helpers
    for (const signal of activeSignals) {
      // Safe radius (default 100m, max 2000m)
      const radius = Math.min(signal.profiles?.serendipity_radius_meters || 100, 2000)

      // Use RPC to get nearby users (excluding self)
      // We reuse the existing logic or a new direct query?
      // Let's use a direct PostGIS query via RPC for efficiency

      const { data: nearbyUsers, error: nearbyError } = await supabase
        .rpc('get_nearby_users_for_matching', {
          p_lat: signal.location.coordinates[1],
          p_long: signal.location.coordinates[0],
          p_radius_meters: radius,
          p_exclude_user_id: signal.user_id
        })

      if (nearbyError) {
        console.error(`❌ Error finding nearby users for signal ${signal.id}:`, nearbyError)
        continue
      }

      if (!nearbyUsers || nearbyUsers.length === 0) continue

      // 3. Match Logic: Simple First-Fit (or Score-based later)
      // Pick the closest or "best" one. For now, try up to 3 nearby users.

      for (const candidate of nearbyUsers.slice(0, 3)) {
        // AUTOMATED MATCH PROPOSAL
        // We use the System ID (null in Auth context for Service Role) or a specific Bot ID?
        // Service Role bypasses RLS, so we can just insert or call suggest_match.

        // Call suggest_match RPC
        // Since we are running as Service Role, we might need to impersonate or update the RPC 
        // to accept a "system_trigger" flag. 
        // Or we can just insert into serendipity_matches directly.

        const { data: matchResult, error: matchError } = await supabase
          .rpc('system_propose_match', {
            p_struggler_id: signal.user_id,
            p_helper_id: candidate.id,
            p_reason: `Nearby: ${signal.subject}`,
            p_signal_id: signal.id
          })

        if (!matchError && matchResult?.success) {
          console.log(`🎉 Match Proposed: ${signal.user_id} <-> ${candidate.id}`)
          matchCount++

          // Only match 1 helper per signal per run to avoid spam
          break
        } else if (matchError) {
          console.error(`⚠️ Match proposal failed:`, matchError)
        }
      }
    }

    return new Response(
      JSON.stringify({ success: true, matches_proposed: matchCount }),
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

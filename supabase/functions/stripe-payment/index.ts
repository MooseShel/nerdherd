// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import Stripe from 'https://esm.sh/stripe@14.14.0'
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

console.log("Stripe Payment Function Initialized (v2 - Customer Support)")

Deno.serve(async (req) => {
  const url = new URL(req.url)
  const path = url.pathname.replace(/\/+$/, '')

  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, stripe-signature',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // -------------------------------------------------------------
  // WEBHOOK HANDLER (Unchanged mostly)
  // -------------------------------------------------------------
  if (req.method === 'POST' && path.endsWith('/webhook')) {
    const signature = req.headers.get('stripe-signature')
    if (!signature) return new Response('No signature', { status: 400 })

    try {
      const body = await req.text()
      const event = stripe.webhooks.constructEvent(
        body,
        signature,
        Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? ''
      )
      console.log(`🔔 Webhook received: ${event.type}`)

      if (event.type === 'payment_intent.succeeded') {
        const paymentIntent = event.data.object
        const { user_id, amount_raw } = paymentIntent.metadata
        if (user_id && amount_raw) {
          console.log(`💰 Crediting user ${user_id} with ${amount_raw}`)
          const { error } = await supabase.rpc('handle_successful_payment', {
            p_user_id: user_id,
            p_amount: parseFloat(amount_raw),
            p_stripe_id: paymentIntent.id
          })
          if (error) console.error('Error updating wallet via RPC:', error)
        }
      }
      return new Response(JSON.stringify({ received: true }), { headers: { 'Content-Type': 'application/json' }, status: 200 })
    } catch (err) {
      console.error(`❌ Webhook Error: ${err.message}`)
      return new Response(`Webhook Error: ${err.message}`, { status: 400 })
    }
  }

  // -------------------------------------------------------------
  // MAIN PAYMENT/SETUP LOGIC
  // -------------------------------------------------------------
  try {
    const { amount, currency = 'usd', customer_email, description, user_id, mode = 'payment' } = await req.json()

    if (!user_id) throw new Error('User ID is required')

    // 1. GET OR CREATE STRIPE CUSTOMER
    const customerId = await getOrCreateCustomer(user_id, customer_email)

    // 2. SETUP MODE (Add Card)
    if (mode === 'setup') {
      // Create Ephemeral Key for Customer Sheet
      const ephemeralKey = await stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: '2023-10-16' }
      )
      // Create SetupIntent
      const setupIntent = await stripe.setupIntents.create({
        customer: customerId,
        automatic_payment_methods: { enabled: true }, // or 'card'
      })

      return new Response(JSON.stringify({
        setupIntent: setupIntent.client_secret,
        ephemeralKey: ephemeralKey.secret,
        customer: customerId,
        publishableKey: Deno.env.get('STRIPE_PUBLISHABLE_KEY') // Optional convenience
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

    // 3. PORTAL MODE (Manage Cards on Web)
    if (mode === 'portal') {
      const session = await stripe.billingPortal.sessions.create({
        customer: customerId,
        return_url: 'https://nerd-herd-one.vercel.app/wallet', // Fallback to a valid origin or dynamic from req
      })
      return new Response(JSON.stringify({ url: session.url }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // 4. PAYMENT MODE (Charge)
    if (!amount) throw new Error('Amount is required for payment mode')

    // Create Ephemeral Key for reusing saved cards
    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: '2023-10-16' }
    )

    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100),
      currency: currency,
      description: description,
      customer: customerId, // Attach to customer!
      setup_future_usage: 'off_session', // Save card for future!
      receipt_email: customer_email,
      automatic_payment_methods: { enabled: true },
      metadata: {
        user_id: user_id,
        amount_raw: amount.toString(),
      },
    })

    return new Response(
      JSON.stringify({
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
        ephemeralKey: ephemeralKey.secret, // Required for PaymentSheet
        customer: customerId,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 },
    )

  } catch (error) {
    console.error(error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
    )
  }
})

// Helper: Sync Supabase User -> Stripe Customer
async function getOrCreateCustomer(userId: string, email: string): Promise<string> {
  // 1. Check if user already has a stripe_customer_id in DB
  const { data, error } = await supabase
    .from('profiles')
    .select('stripe_customer_id')
    .eq('user_id', userId)
    .single()

  if (error && error.code !== 'PGRST116') {
    console.error("Error fetching profile:", error)
  }

  if (data?.stripe_customer_id) {
    try {
      // VERIFY: Check if customer still exists in Stripe
      const existingCustomer = await stripe.customers.retrieve(data.stripe_customer_id)
      if (existingCustomer && !existingCustomer.deleted) {
        return existingCustomer.id
      }
      console.log(`Stripe Customer ${data.stripe_customer_id} found in DB but is deleted/invalid in Stripe. Creating new one.`)
    } catch (err) {
      console.warn(`Stripe Customer ${data.stripe_customer_id} failed retrieval: ${err.message}. Creating new one.`)
    }
  }

  // 2. Create new Stripe Customer
  console.log(`Creating new Stripe Customer for ${email}`)
  const customer = await stripe.customers.create({
    email: email,
    metadata: { supabase_id: userId }
  })

  // 3. Save to DB
  const { error: updateError } = await supabase
    .from('profiles')
    .update({ stripe_customer_id: customer.id })
    .eq('user_id', userId)

  if (updateError) console.error("Error saving stripe_customer_id:", updateError)

  return customer.id
}

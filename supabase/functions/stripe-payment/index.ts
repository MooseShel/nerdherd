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

console.log("Stripe Payment Function Initialized")

Deno.serve(async (req) => {
  const url = new URL(req.url)
  const path = url.pathname.replace(/\/+$/, '') // Remove trailing slash

  // CORS Headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, stripe-signature',
  }

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // -------------------------------------------------------------
  // WEBHOOK HANDLER
  // -------------------------------------------------------------
  if (req.method === 'POST' && path.endsWith('/webhook')) {
    const signature = req.headers.get('stripe-signature')
    if (!signature) {
      return new Response('No signature', { status: 400 })
    }

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

          // Use RPC to credit wallet securely
          const { error } = await supabase.rpc('handle_successful_payment', {
            p_user_id: user_id,
            p_amount: parseFloat(amount_raw),
            p_stripe_id: paymentIntent.id
          })

          if (error) {
            console.error('Error updating wallet via RPC:', error)
            return new Response('Database error', { status: 500 })
          }
        }
      }

      return new Response(JSON.stringify({ received: true }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    } catch (err) {
      console.error(`❌ Webhook Error: ${err.message}`)
      return new Response(`Webhook Error: ${err.message}`, { status: 400 })
    }
  }

  // -------------------------------------------------------------
  // PAYMENT INTENT CREATION (Existing Logic)
  // -------------------------------------------------------------
  try {
    const { amount, currency = 'usd', customer_email, description, user_id } = await req.json()

    if (!amount || !user_id) {
      throw new Error('Amount and User ID are required')
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100),
      currency: currency,
      description: description,
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
        paymentIntentId: paymentIntent.id
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error(error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})

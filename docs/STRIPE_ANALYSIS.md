# Stripe Integration Analysis & Production Roadmap

## 1. Current State Assessment
The current implementation (`PaymentService` + `stripe-payment` Edge Function) operates on a **"Guest Checkout"** model.

### ✅ What Works
- **One-time Deposits**: Users can top up their wallet using a card.
- **Payment Intents**: The backend successfully creates a payment intent for a specific amount.
- **Webhooks**: The Edge Function has a webhook handler (`handle_successful_payment` RPC) to securely credit the wallet.

### ❌ What is Missing (The "Add Card" Gap)
- **No Stripe Customer Object**: The current code does not create or reuse a `Customer` object in Stripe. Every transaction is treated as a new "guest", preventing card saving.
- **No Setup Intents**: To add a card *without* charging it (users "Add Card" flow), we need `SetupIntents`.
- **No Management UI**: There is no screen to view, allow default, or delete saved cards.
- **Ephemeral Keys**: The Stripe Mobile SDK requires an "Ephemeral Key" to securely let the app manage a specific Customer's payment methods.

## 2. Production Critical Gaps
1.  **Saved Cards**: To enable "1-click" top-ups or future auto-charges (e.g., subscription or canceling fees), we **must** switch to the **Customer + SetupIntent** flow.
2.  **Database Schema**: We need to store the `stripe_customer_id` in your `public.profiles` table so we map one App User <-> One Stripe Customer.
3.  **Webhook Security**: You must ensure the `STRIPE_WEBHOOK_SECRET` is set in Supabase Secrets and the endpoint URL is configured in the Stripe Dashboard.

## 3. Recommended Roadmap

### Phase 1: Database & Backend (The Foundation)
1.  **Update Database**: Add `stripe_customer_id` (text) to `profiles`.
2.  **Enhance Edge Function**:
    -   **Mode A (Payment)**: Check if user has `stripe_customer_id`. If not, `stripe.customers.create`. usage `payment_intent` with `customer` and `setup_future_usage: 'on_session'`.
    -   **Mode B (Setup)**: Create a `setup_intent` (for "Add Card" screen) attached to the customer.
    -   **Mode C (Ephemeral Keys)**: Valid key for the app to list cards.

### Phase 2: Client-Side "Add Card" Feature
1.  **New UI**: logical "Payment Methods" screen.
2.  **Stripe Customer Sheet**: Use `Stripe.instance.initCustomerSheet` (Flutter SDK feature) which provides a pre-built UI to list, add, and remove cards stored on the Customer object.

### Phase 3: Client-Side "Pay with Saved Card"
1.  Update `deposit` logic to use the `CustomerSheet` or pass the standard Payment Sheet with the Customer ID attached, allowing users to pick their saved card.

## 4. Immediate Action Plan (How I can help)
If you approve, I can execute **Phase 1 and 2** right now:

1.  **SQL**: Add `stripe_customer_id` column.
2.  **Backend**: Rewrite `stripe-payment` to handle Customer Creation and Ephemeral Keys.
3.  **Frontend**: Add a "Manage Cards" button in Wallet Page that opens the Stripe UI.

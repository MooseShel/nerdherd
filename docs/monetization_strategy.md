# Monetization Strategy Roadmap

this document outlines the potential revenue streams for the application.

## 1. Platform Service Fee (Selected for MVP) 💰 [ IMPLEMENTED ✅ ]
*   **Concept**: Charge a transaction fee on every P2P payment (e.g., Student paying Tutor).
*   **Model**: Percentage-based (e.g., 5-10%) or Flat Fee. (Implemented: 20%)
*   **Implementation**:
    *   Modify `process_payment` RPC. (Done)
    *   Split incoming payment: X% to Tutor, Y% to Platform Wallet. (Done)
    *   Requires a "Platform/System" user ID to collect fees. (Done)

## 2. "NerdHerd Pro" Subscription (Freemium) ⭐️
*   **Concept**: Monthly recurring subscription for advanced features.
*   **Price Point**: ~$4.99/mo.
*   **Pro Features**:
    *   **Ghost Mode**: Hide location (currently free).
    *   **Who Viewed Me**: Analytics on profile visitors.
    *   **Verified Badge**: Visual trust indicator.
    *   **Priority Listing**: Appear higher in Tutor searches.
    *   **Ad-Free**: If we implement ads later.

## 3. Sponsored Study Spots (Local Ads) 📍 [ IMPLEMENTED ✅ ]
*   **Concept**: Local businesses (cafes, libraries, bookstores) pay for visibility.
*   **Features**:
    *   **Gold Pin**: Larger, distinct map marker. (Done)
    *   **Featured Placement**: Top of "Nearby Spots" list. (Done via logic)
    *   **Deals/Coupons**: "Show this app for 10% off coffee" attached to the spot details. (Done via Promo Text)

## 4. University Partnerships (B2B) 🏫
*   **Concept**: Sell aggregated data and enterprise features to Universities.
*   **Features**:
    *   **Campus Dashboard**: Real-time heatmaps of study activity.
    *   **Subject Demand Analytics**: Insights into which courses students are struggling with (high tutoring demand).
    *   **Official Verified Tutors**: University-employed tutors get special badges.

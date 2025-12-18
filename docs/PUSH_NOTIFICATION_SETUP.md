# Push Notification Setup Guide

## Step 2: Deploy Edge Function

This step deploys the code that actually talks to Google/Apple servers to send the notification.

### A. Get Firebase Credentials
1.  Go to the [Firebase Console](https://console.firebase.google.com/).
2.  Open your project.
3.  Click the **Gear Icon** (Project Settings) -> **Service accounts** tab.
4.  Click **Generate new private key**.
5.  This will download a `.json` file. Open it with a text editor.
6.  **Copy the entire content** of this JSON file. It looks like:
    ```json
    {
      "type": "service_account",
      "project_id": "nerd-herd-...",
      ...
    }
    ```
    *Stop! Do not modify the text. Just copy it.*

### B. Set the Secret in Supabase
This allows your Edge Function to log in to Firebase securely.
1.  Go to the **Supabase Dashboard** -> **Edge Functions** (on the left sidebar).
2.  If you don't see "Edge Functions", look for **Settings** -> **Edge Functions**.
3.  Click **Add new secret** (or "Secrets" button).
4.  **Name**: `FIREBASE_SERVICE_ACCOUNT`
5.  **Value**: Paste the JSON content you copied in Step A.
6.  Click **Save**.

### C. Deploy the Function
You need to run this from your terminal (where you have the code).

1.  Open your terminal/command prompt to the project folder (`c:\Users\Husse\Documents\Anti`).
2.  Run this command:
    ```powershell
    supabase functions deploy push --no-verify-jwt
    ```
3.  If asked for a project reference, select your project.
4.  Once finished, it will give you a URL like:
    `https://[YOUR_PROJECT_REF].supabase.co/functions/v1/push`
    **Copy this URL.**

---

## Step 3: Setup Database Webhook

This step tells the database: *"Hey, whenever a new row is added to the `notifications` table, call that URL from Step 2!"*

1.  Go to the **Supabase Dashboard**.
2.  Click on **Database** (Sidebar) -> **Webhooks**.
3.  Click **Create a new webhook**.
4.  Fill in the form:
    *   **Name**: `Send Push Notification`
    *   **Table**: Select `public.notifications`.
    *   **Events**: Check `INSERT` (we only want to notify on new items).
    *   **Type**: Select `HTTP Request` (or "Supabase Edge Functions" if available, but HTTP is standard).
    *   **HTTP Method**: `POST`.
    *   **URL**: Paste the URL you copied in Step 2C.
    *   **HTTP Headers**:
        *   Click "Add Header".
        *   Name: `Authorization`
        *   Value: `Bearer [YOUR_ANON_KEY]` (Find this in Settings -> API).
        *   *Note: If your function checks for the Service Role key, use that instead, but usually Anon is fine if you enabled `--no-verify-jwt`.*
5.  Click **Confirm** / **Create Config**.

## Verification
1.  Open your App on a real device (or emulator with Google Play Services).
2.  The app should upload an FCM token to the `profiles` table. Check the table to verify columns `fcm_token` are populated.
3.  Send a message from User A to User B.
4.  A new row should appear in `notifications`.
5.  The Webhook should fire (you can check "Webhook Logs" in Supabase).
6.  User B should receive a push notification!

# Push Notification Master Diagnostic Guide

Push notifications are a chain reaction. We need to find which link in the chain is broken.

## 🛑 Status Check: What was done?

| Component | Status | Who Did It? | How to Verify? |
| :--- | :--- | :--- | :--- |
| **Flutter Code** | ✅ Done | **AI** | Code requests permissions and listens for tokens. |
| **Database Schema** | ✅ Done | **AI** | `fix_push_complete.sql` added columns and triggers. |
| **Edge Function Code** | ✅ Done | **AI** | `supabase/functions/push` exists. |
| **Deploy Function** | ? | **User** | Did you run `supabase functions deploy`? |
| **Set Secrets** | ? | **User** | Did you upload `FIREBASE_SERVICE_ACCOUNT` json? |
| **Setup Webhook** | ? | **User** | Did you create the Webhook in Dashboard? |
| **Apple/Firebase Config** | ? | **User** | Did you upload APNs Keys to Firebase Console? |

---

## 🕵️‍♂️ Phase 1: The Trace (Do this now)

Follow these steps **in order**. Stop at the first "NO".

### Step 1: Check the Token (The App)
1.  Run the app on a **Real Device**.
2.  Go to **Supabase Dashboard -> Table Editor -> `profiles`**.
3.  Find your user row.
4.  **Is the `fcm_token` column filled with a long text string?**
    *   **YES**: The App is working. Proceed to Step 2.
    *   **NO / NULL**: The App failed to get a token.
        *   *Cause*: `GoogleService-Info.plist` is missing/wrong OR Apple Developer Account "Push Notifications" capability is off OR "APNs Key" not uploaded to Firebase Console.

### Step 2: Check the Notification (The DB)
1.  Send a message from User A to User B (using the app).
2.  Go to **Supabase Dashboard -> Table Editor -> `notifications`**.
3.  **Is there a new row created just now?**
    *   **YES**: The Database Triggers are working. Proceed to Step 3.
    *   **NO**: The SQL Triggers didn't fire. Re-run `database/fix_push_complete.sql`.

### Step 3: Check the Webhook (The Handshake)
1.  Go to **Supabase Dashboard -> Database -> Webhooks**.
2.  Click on the `Send Push Notification` webhook you created.
3.  Look at the **History / Logs** section.
4.  **Do you see a recent event (200 OK or Error)?**
    *   **200 OK**: Supabase successfully called the Edge Function. Proceed to Step 4.
    *   **401/500 Error**: The Webhook URL is wrong or the Function crashed.
    *   **NO LOGS**: The webhook isn't configured correctly. Make sure it's set to `INSERT` on `notifications`.

### Step 4: Check the Edge Function (The Sender)
1.  Go to **Supabase Dashboard -> Edge Functions**.
2.  Click on `push`.
3.  Click **Logs** (Invocations).
4.  **What do the logs say?**
    *   "Successfully sent message": It worked (Blame Apple/Phone settings).
    *   "Auth Error": Your `FIREBASE_SERVICE_ACCOUNT` secret is wrong.
    *   "Firebase Error": Firebase rejected it (Certificates or Project ID mismatch).

---

## 🔧 Phase 2: Solutions based on Findings

### If Step 1 Failed (No Token)
**Problem**: The app is not asking Apple for a token because the "Push Notifications" capability is missing.
**Solution (CRITICAL for iOS):**
1.  **Open Xcode**: Open the file `ios/Runner.xcworkspace` in Xcode on your Mac.
2.  **Select Project**: Click "Runner" in the left sidebar (file tree).
3.  **Select Target**: Click "Runner" in the generic "Targets" list in the middle pane.
4.  **Capabilities**: Click the **"Signing & Capabilities"** tab at the top.
5.  **Add Push**: Click the **"+ Capability"** button (top left of the tab).
    *   Search for **"Push Notifications"**.
    *   Double-click it to add it.
6.  **Add Background Mode**: Click **"+ Capability"** again.
    *   Search for **"Background Modes"**.
    *   Add it.
    *   Check the box **"Remote notifications"**.
7.  **Rebuild**: Now build the app again (`flutter run` or Codemagic).

**For Android**:
*   Ensure `google-services.json` is in `android/app/`.
*   Ensure the package name in that JSON matches `com.nerdherd.app`.

### If Step 2 Failed (No Notification Row)
*   **Action**: Re-run the fix script.
*   **Check**: Copy contents of `database/fix_push_complete.sql` and run it in Supabase SQL Editor again.

### If Step 3 Failed (Webhook Error)
*   **Check**:
    *   URL should look like: `https://[PROJECT-REF].supabase.co/functions/v1/push`
    *   Headers: `Authorization: Bearer [ANON_KEY]` (Try Anon key if Service Role fails).
    *   Ensure the function is actually deployed.

### If Step 4 Failed (Function Error)
*   **Check**:
    *   Did you set the secret? `supabase secrets set FIREBASE_SERVICE_ACCOUNT=@firebase-key.json`
    *   Is the JSON valid?
    *   Did you upload the **APNs Authentication Key** (.p8 file) to Firebase Console -> Project Settings -> Cloud Messaging -> Apple app configuration? **This is CRITICAL for iOS.**

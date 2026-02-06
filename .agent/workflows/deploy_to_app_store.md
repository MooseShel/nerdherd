---
description: How to release the app to the App Store using Codemagic and App Store Connect
---

# Deploy to App Store

This workflow guides you through triggering a Cloud Build, submitting to TestFlight, and releasing to the App Store.

## 1. Trigger the Build (Codemagic)
1.  **Login** to [Codemagic](https://codemagic.io/).
2.  Navigate to the **Nerd Herd** application.
3.  Click **Start new build**.
4.  Select the **Release / App Store** workflow (ensure it points to the `master` branch we just pushed).
5.  Click **Start build**.
    *   *Codemagic will compile the app, sign it with your certificates, and upload the `.ipa` directly to App Store Connect.*
    *   *Wait for the build to finish (typically 15-30 mins).*

## 2. Verify in App Store Connect
1.  **Login** to [App Store Connect](https://appstoreconnect.apple.com/).
2.  Go to **My Apps** -> **Nerd Herd**.
3.  Click on the **TestFlight** tab at the top.
4.  You should see your new version (e.g., `1.0.0 (50)`) processing or ready.
    *   *If "Missing Compliance", click "Manage" -> Answer "No" to the encryption questions (since you are using standard HTTPS).*

## 3. Submit for Review
1.  Go to the **App Store** tab (main dashboard for the app).
2.  In the left sidebar, under **Production**, verify you are on **1.0 Prepare for Submission** (or click "+" to create a new version if needed).
3.  **Build Section**:
    *   Scroll down to the "Build" section.
    *   Click **Add Build**.
    *   Select the build `1.0.0 (50)` you just verified in TestFlight.
    *   Click **Done**.
4.  **Metadata Check**:
    *   Ensure all screenshots, description, keywords, and support URL are filled out.
    *   Ensure "App Review Information" (Sign-in required) has the **Demo Account** we prepared earlier.
5.  **Submit**:
    *   Click **Add for Review** (top right).
    *   Click **Submit to App Review**.

## 4. Release (After Approval)
*   Review typically takes 24-48 hours.
*   Once approved, the status changes to **Ready for Sale** (if you chose "Automatically release") or **Pending Developer Release**.
*   If pending, go back to App Store Connect and click **Release This Version**.

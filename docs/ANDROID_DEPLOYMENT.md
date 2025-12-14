# Android Play Store Deployment Guide

Since we are using GitHub Actions for "Cloud Build", you can automate the signing process.

## 1. Monitor Builds
The current workflow builds a **Release APK** but it is signed with the default debug key (or unsigned depending on Gradle config, though usually Flutter release builds require signing config). By default, Flutter release builds might fail without a signing config or produce an unsigned APK.

**Note**: The current setup builds an APK useful for testing. For the Play Store, you need an App Bundle (`.aab`) signed with your upload key.

## 2. Generate Upload Keystore
Run this on your local machine if you haven't already:
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## 3. Add Secrets to GitHub
Go to your GitHub Repo > Settings > Secrets and variables > Actions.

Add these secrets:
- `ANDROID_KEYSTORE_BASE64`: Base64 encoded content of your `upload-keystore.jks`.
- `ANDROID_KEYSTORE_PASSWORD`: Password for the keystore.
- `ANDROID_KEY_ALIAS`: Your key alias (e.g., `upload`).
- `ANDROID_KEY_PASSWORD`: Password for the key.

## 4. Update Workflow & Gradle
To fully automate release:
1.  Video/Docs on how to configure `android/app/build.gradle` to read these secrets from environment variables.
2.  Update the workflow to decode the keystore file and pass the variables.

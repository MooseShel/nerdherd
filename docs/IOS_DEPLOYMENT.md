# iOS App Store Deployment Guide

Since we are using GitHub Actions for "Cloud Build", you need to provide Apple Developer credentials so the cloud server can sign your app.

## 1. Get Apple Developer Credentials
You must have an enrolled Apple Developer Program account ($99/year).

1.  **Issuer ID**: Found in App Store Connect > Users and Access > Integrations > Key Details.
2.  **Key ID**: Create a new API Key in App Store Connect.
3.  **API Private Key**: Download the `.p8` file for the key you just created.
4.  **Distribution Certificate**: Export your distribution certificate as a `.p12` file from Keychain Access (requires Mac initially to generate CSR, or use fastlane matching).
5.  **Provisioning Profile**: A "Distribution" provisioning profile for `com.example.nerdherd`.

## 2. Add Secrets to GitHub
Go to your GitHub Repo > Settings > Secrets and variables > Actions > New repository secret.

Add the following secrets:
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_PRIVATE_KEY` (Content of .p8 file)
- `DISTRIBUTION_CERTIFICATE_BASE64` (Base64 encoded .p12 file)
- `DISTRIBUTION_CERTIFICATE_PASSWORD` (Password for the .p12 file)
- `PROVISIONING_PROFILE_BASE64` (Base64 encoded .mobileprovision file)

## 3. Update Workflow
Once you have these secrets, update `.github/workflows/ios_build.yml` to use `flutter build ipa --export-options-plist=ios/Runner/ExportOptions.plist` which will produce the uploadable binary.

For now, the current workflow verifies that the app **builds** correctly without signing.

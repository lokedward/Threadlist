# Gmail Integration Setup Guide

## Overview
This guide explains how to set up Gmail OAuth2 integration for the Email Import feature.

---

## Prerequisites

1. **Google Cloud Project** - Create at [console.cloud.google.com](https://console.cloud.google.com)
2. **OAuth 2.0 Client ID** - For iOS application
3. **Bundle Identifier** - Your app's bundle ID (e.g., `com.threaddit.app`)

---

## Step 1: Configure Google Cloud Project

### Create OAuth 2.0 Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project (or create new one)
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth client ID**
5. Select **iOS** as application type
6. Enter your **Bundle Identifier** (e.g., `com.threaddit.app`)
7. Click **Create**
8. Download the configuration file (`GoogleService-Info.plist`)

### Enable Gmail API

1. Go to **APIs & Services** → **Library**
2. Search for "Gmail API"
3. Click **Enable**

---

## Step 2: Install Google Sign-In SDK

### Via CocoaPods

Add to your `Podfile`:

```ruby
pod 'GoogleSignIn', '~> 7.0'
```

Then run:
```bash
pod install
```

### Via Swift Package Manager

1. In Xcode: **File** → **Add Package Dependencies**
2. Enter: `https://github.com/google/GoogleSignIn-iOS`
3. Select version 7.0.0 or later

---

## Step 3: Configure Xcode Project

### Add GoogleService-Info.plist

1. Drag `GoogleService-Info.plist` into your Xcode project
2. Ensure it's added to your app target
3. Do NOT add to version control (add to `.gitignore`)

### Update Info.plist

Add URL scheme for OAuth redirect:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR-CLIENT-ID` with the value from `GoogleService-Info.plist`.

---

## Step 4: Update EmailOnboardingService

Replace the placeholder `requestGmailAccess()` method:

```swift
import GoogleSignIn

private func requestGmailAccess() async throws -> GmailToken {
    guard let clientID = GIDConfiguration.default?.clientID else {
        throw EmailError.authenticationFailed
    }
    
    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config
    
    // Request Gmail read-only scope
    let scopes = ["https://www.googleapis.com/auth/gmail.readonly"]
    
    return try await withCheckedThrowingContinuation { continuation in
        Task { @MainActor in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                continuation.resume(throwing: EmailError.authenticationFailed)
                return
            }
            
            GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: scopes
            ) { result, error in
                if let error = error {
                    continuation.resume(throwing: EmailError.authenticationFailed)
                    return
                }
                
                guard let user = result?.user,
                      let accessToken = user.accessToken.tokenString else {
                    continuation.resume(throwing: EmailError.authenticationFailed)
                    return
                }
                
                let token = GmailToken(
                    accessToken: accessToken,
                    expiresAt: user.accessToken.expirationDate ?? Date().addingTimeInterval(3600)
                )
                
                continuation.resume(returning: token)
            }
        }
    }
}

private func revokeGmailToken(_ token: GmailToken) async throws {
    // Revoke access
    GIDSignIn.sharedInstance.signOut()
    
    // Also revoke server-side
    let url = URL(string: "https://oauth2.googleapis.com/revoke?token=\(token.accessToken)")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    _ = try? await URLSession.shared.data(for: request)
}
```

---

## Step 5: Update Config.swift

Add Gmail configuration:

```swift
struct AppConfig {
    // ... existing API keys ...
    
    // MARK: - Gmail OAuth
    static let gmailClientID: String = {
        // Read from GoogleService-Info.plist
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let clientID = dict["CLIENT_ID"] as? String else {
            fatalError("GoogleService-Info.plist missing or invalid")
        }
        return clientID
    }()
}
```

---

## Step 6: Testing

### Test OAuth Flow

1. Build and run the app
2. Tap "Import from Gmail"
3. You should see Google Sign-In dialog
4. Sign in with a Gmail account
5. Grant permissions for read-only access
6. Verify token is received

### Test Token Revocation

1. Complete import flow
2. Verify token is auto-revoked
3. Check Gmail account permissions at [myaccount.google.com/permissions](https://myaccount.google.com/permissions)
4. Threaddit should NOT appear in connected apps after revocation

---

## Security Checklist

- [ ] `GoogleService-Info.plist` added to `.gitignore`
- [ ] Only `gmail.readonly` scope requested
- [ ] Token revoked after processing
- [ ] No server-side email storage
- [ ] Privacy Manifest (`PrivacyInfo.xcprivacy`) included in project
- [ ] Privacy Policy updated with email access disclosure

---

## Troubleshooting

### "Authorization Error"
- Verify Gmail API is enabled in Google Cloud Console
- Check bundle ID matches OAuth client configuration
- Ensure URL scheme is correctly configured

### "Invalid Client"
- Verify `GoogleService-Info.plist` is in project
- Check client ID matches Google Cloud Console
- Rebuild project

### "Token Expired"
- Tokens expire after 1 hour (as configured)
- Request new token for additional imports

---

## Privacy Policy Template

Add this section to your Privacy Policy:

```markdown
## Email Access (Optional Feature)

Threaddit offers an optional feature to import wardrobe items from Gmail 
order confirmations.

**What We Access**: 
When you grant permission, we temporarily access your Gmail to search for 
emails with subject lines like "Order Shipped" or "Order Delivered".

**What We Extract**: 
Product names, images, and basic details (size, color, brand) from 
retailer order confirmations.

**Processing**: 
All email processing happens locally on your device. We never upload 
email content to our servers.

**Duration**: 
Gmail access is temporary and automatically revoked when processing 
completes or after 1 hour, whichever comes first.

**Revocation**: 
You can manually revoke access anytime at 
[myaccount.google.com/permissions](https://myaccount.google.com/permissions).

**Supported Retailers**: 
Amazon, Nike, Zara, and other major clothing retailers.
```

---

## Next Steps

1. Implement `searchOrderEmails()` - Call Gmail API to fetch messages
2. Implement `parseEmails()` - Parse HTML and extract product data
3. Create retailer-specific parsers (Amazon, Nike, Zara)
4. Add error handling and user feedback
5. Test with real Gmail accounts

See `email_onboarding_plan.md` for full implementation details.

# Xcode Configuration Guide for Config.swift

## ✅ Step-by-Step Setup

### 1. Add Config.swift to Xcode Project

**If Config.swift is not yet in Xcode**:

1. Open your Xcode project
2. Right-click on the `Threaddit` folder in the Project Navigator
3. Select "Add Files to Threaddit..."
4. Navigate to `c:\Users\loked\Development\ClosetTracker\Threaddit\Config.swift`
5. **IMPORTANT**: Make sure these options are selected:
   - ✅ "Copy items if needed" (UNCHECK this - file is already in place)
   - ✅ "Create groups"
   - ✅ "Add to targets: Threaddit" (CHECK this)
6. Click "Add"

### 2. Verify Config.swift is in Build

1. In Xcode, select your project in the Navigator
2. Select the "Threaddit" target
3. Go to "Build Phases" tab
4. Expand "Compile Sources"
5. **Look for Config.swift in the list**
   - ✅ If it's there: You're good!
   - ❌ If it's not there: Click the "+" button and add it

### 3. Verify Git is Ignoring It

**Test in Terminal**:
```bash
cd c:\Users\loked\Development\ClosetTracker\Threaddit
git status
```

**Expected Output**:
```
On branch master
nothing to commit, working tree clean
```

**If Config.swift shows up as untracked**:
```bash
# View gitignore
cat .gitignore

# Should see "Config.swift" in the file
# If not, add it:
echo "Config.swift" >> .gitignore
git add .gitignore
git commit -m "Ensure Config.swift is gitignored"
```

### 4. Test API Keys are Accessible

**Quick Test**:
1. Open `StylistService.swift` in Xcode
2. Add a temporary test in the `generateModelPhoto` function:

```swift
// TEMPORARY TEST - Remove after verification
print("🔑 Google API Key: \(AppConfig.googleAPIKey.prefix(10))...")
print("🔑 Stability API Key: \(AppConfig.stabilityAPIKey.prefix(10))...")
```

3. Build and run the app (⌘R)
4. Check Xcode console - you should see:
```
🔑 Google API Key: AIzaSyC6wq...
🔑 Stability API Key: sk-WBcBVr3...
```

5. **Remove the print statements** after verification!

---

## 🔒 Security Verification Checklist

### ✅ Config.swift Should:
- [x] Be in your local project directory
- [x] Be included in Xcode target (Build Phases → Compile Sources)
- [x] Be listed in `.gitignore`
- [x] **NOT** appear in `git status` output
- [x] **NOT** be in your GitHub repository

### ❌ Config.swift Should NOT:
- [ ] Be committed to Git
- [ ] Be visible in GitHub
- [ ] Be shared with teammates (they need their own)

---

## 🚨 If You Accidentally Committed Config.swift

**If you see Config.swift in `git status` or on GitHub**:

```bash
# Remove from Git tracking (keeps local file)
git rm --cached Config.swift

# Commit the removal
git commit -m "Remove Config.swift from version control"

# Push to remote
git push origin master

# Verify .gitignore has Config.swift
echo "Config.swift" >> .gitignore
git add .gitignore
git commit -m "Add Config.swift to gitignore"
git push origin master
```

---

## 📱 Alternative: Environment Variables (Advanced)

**For production/TestFlight**, consider using Xcode environment variables:

1. In Xcode, go to: Product → Scheme → Edit Scheme
2. Select "Run" → "Arguments" tab
3. Add Environment Variables:
   - `GOOGLE_API_KEY`: `AIzaSyC6wqlqTCkQRylizaKdOSksExUzPxo5IPw`
   - `STABILITY_API_KEY`: `sk-WBcBVr3fqrTsEJf2nAmdygqDtgsOpxarHyqELuZ3gpZDthvY`

4. Update `Config.swift`:
```swift
struct AppConfig {
    static let googleAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] {
            return envKey
        }
        return "AIzaSyC6wqlqTCkQRylizaKdOSksExUzPxo5IPw" // fallback
    }()
    
    static let stabilityAPIKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["STABILITY_API_KEY"] {
            return envKey
        }
        return "sk-WBcBVr3fqrTsEJf2nAmdygqDtgsOpxarHyqELuZ3gpZDthvY" // fallback
    }()
    
    static let imagenEndpoint = "https://us-central1-aiplatform.googleapis.com/v1/projects/threadlist/locations/us-central1/publishers/google/models/imagen-3.0-generate-001:predict"
    static let stabilityEndpoint = "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image"
}
```

**Benefits**:
- Different keys for Debug vs Release builds
- Easier team collaboration (each dev uses their own keys)
- Better for CI/CD pipelines

---

## 🧪 Final Verification Steps

1. **Build the project** (⌘B)
   - Should compile without errors
   - Config.swift should be recognized

2. **Run the app** (⌘R)
   - Navigate to AI Stylist
   - Try generating a look
   - Check console for any "API key not found" errors

3. **Check Git status** one more time:
```bash
git status
# Should NOT list Config.swift
```

4. **Check GitHub** (if you've pushed):
   - Go to your repo: https://github.com/lokedward/Threaddit
   - Search for "Config.swift"
   - Should return "No results"

---

## ✅ You're Ready If:

- Config.swift compiles in Xcode ✅
- App can read `AppConfig.googleAPIKey` ✅
- Git ignores Config.swift ✅
- Config.swift is NOT on GitHub ✅

Your API keys are now **secure and functional**! 🔐

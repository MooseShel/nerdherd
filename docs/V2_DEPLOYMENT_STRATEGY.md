# Nerd Herd 2.0 Deployment Strategy
## Safe Parallel Development Without Impacting v1.0

---

## Recommended Approach: Feature Flags + Separate Supabase Project

### ✅ Best Strategy (Recommended)
Keep everything in the **same repository** but use:
1. **Feature flags** to toggle new features on/off
2. **Separate Supabase project** for development/testing
3. **Git branching strategy** for organized development

### Why This Approach?
- ✅ Maintains single codebase (easier to share bug fixes between versions)
- ✅ Can gradually roll out features to beta users
- ✅ Zero risk to production users
- ✅ Easy to cherry-pick bug fixes from main → dev branch

---

## Implementation Plan

### Phase 1: Repository Setup

#### Option A: Same Repo, Feature Branch (RECOMMENDED)
```bash
# Current structure
main (production v1.0)
  ↓
develop-v2 (Serendipity Engine features)
```

**Steps**:
```bash
# 1. Create new development branch
git checkout -b develop-v2

# 2. Add feature flag system
# (see code below)

# 3. Develop new features with flags disabled by default
```

**Pros**:
- Share bug fixes easily between branches
- Single CI/CD pipeline
- Gradual migration path

**Cons**:
- Need discipline to keep feature flags organized

---

#### Option B: Separate Repository (Alternative)
```bash
# Create new repo
nerd-herd-v2/
```

**Steps**:
```bash
# 1. Create new GitHub repo
gh repo create nerd-herd-v2 --private

# 2. Copy current codebase
cp -r nerd-herd/ nerd-herd-v2/
cd nerd-herd-v2
git init
git remote add origin https://github.com/yourusername/nerd-herd-v2.git

# 3. Develop independently
```

**Pros**:
- Complete isolation
- No risk of accidental merges

**Cons**:
- Bug fixes need to be manually synced
- Harder to share code
- Double the CI/CD setup

---

### Phase 2: Feature Flag System (for Option A)

#### Install Feature Flag Package
```yaml
# pubspec.yaml
dependencies:
  flutter_dotenv: ^5.1.0
  
dev_dependencies:
  build_runner: ^2.4.0
```

#### Create Feature Flag Manager
```dart
// lib/config/feature_flags.dart
class FeatureFlags {
  // Serendipity Engine features
  static const bool enableSerendipityMode = bool.fromEnvironment(
    'ENABLE_SERENDIPITY',
    defaultValue: false, // OFF by default in production
  );
  
  static const bool enableProximityAlerts = bool.fromEnvironment(
    'ENABLE_PROXIMITY_ALERTS',
    defaultValue: false,
  );
  
  static const bool enableStudyConstellation = bool.fromEnvironment(
    'ENABLE_STUDY_CONSTELLATION',
    defaultValue: false,
  );
  
  // Easy way to check if ANY v2 feature is enabled
  static bool get isV2Enabled => 
    enableSerendipityMode || 
    enableProximityAlerts || 
    enableStudyConstellation;
}
```

#### Usage in Code
```dart
// lib/pages/map_section/map_page.dart
Widget build(BuildContext context) {
  return Scaffold(
    floatingActionButton: Column(
      children: [
        // Existing v1.0 buttons
        _buildLocationButton(),
        
        // NEW: Only show if feature enabled
        if (FeatureFlags.enableSerendipityMode)
          _buildSerendipityButton(),
      ],
    ),
  );
}
```

#### Environment-Specific Builds
```bash
# Production build (v1.0 - all flags OFF)
flutter build apk --release

# Beta build (v2.0 - flags ON)
flutter build apk --release \
  --dart-define=ENABLE_SERENDIPITY=true \
  --dart-define=ENABLE_PROXIMITY_ALERTS=true

# Development build (all features ON)
flutter run --dart-define=ENABLE_SERENDIPITY=true \
  --dart-define=ENABLE_PROXIMITY_ALERTS=true \
  --dart-define=ENABLE_STUDY_CONSTELLATION=true
```

---

### Phase 3: Separate Supabase Projects

#### Current Setup
```
Production: nerd-herd-prod (v1.0)
  - URL: https://your-project.supabase.co
  - Users: Real students
```

#### New Setup
```
Production: nerd-herd-prod (v1.0)
  - URL: https://your-project.supabase.co
  - Users: Real students
  - NO CHANGES

Development: nerd-herd-v2-dev (v2.0 testing)
  - URL: https://your-project-v2.supabase.co
  - Users: Test accounts + beta testers
  - NEW TABLES: struggle_signals, compatibility_scores, etc.
```

#### Steps to Create Dev Project
1. Go to https://supabase.com/dashboard
2. Click "New Project"
3. Name: `nerd-herd-v2-dev`
4. Copy schema from production:
   ```bash
   # Export production schema
   supabase db dump --db-url "postgresql://..." > prod_schema.sql
   
   # Import to dev project
   psql "postgresql://dev-project-url" < prod_schema.sql
   
   # Add new v2.0 tables
   psql "postgresql://dev-project-url" < database/serendipity_core.sql
   ```

#### Environment Configuration
```dart
// lib/config/supabase_config.dart
class SupabaseConfig {
  static String get url {
    if (FeatureFlags.isV2Enabled) {
      return const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://your-project-v2.supabase.co', // Dev project
      );
    }
    return 'https://your-project.supabase.co'; // Production
  }
  
  static String get anonKey {
    if (FeatureFlags.isV2Enabled) {
      return const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'dev-anon-key',
      );
    }
    return 'prod-anon-key';
  }
}
```

---

### Phase 4: Git Branching Strategy

```
main (production v1.0)
  ↓
  ├── hotfix/* (urgent production fixes)
  ↓
develop-v2 (v2.0 development)
  ↓
  ├── feature/serendipity-proximity
  ├── feature/serendipity-constellation
  ├── feature/serendipity-ui
```

#### Workflow
```bash
# 1. Start new v2.0 feature
git checkout develop-v2
git pull origin develop-v2
git checkout -b feature/serendipity-proximity

# 2. Develop and test
# ... make changes ...
git add .
git commit -m "feat: add proximity alert system"

# 3. Merge to develop-v2
git checkout develop-v2
git merge feature/serendipity-proximity
git push origin develop-v2

# 4. If production bug found, fix in main
git checkout main
git checkout -b hotfix/chat-crash
# ... fix bug ...
git checkout main
git merge hotfix/chat-crash

# 5. Cherry-pick fix to develop-v2
git checkout develop-v2
git cherry-pick <commit-hash>
```

---

### Phase 5: CI/CD Configuration (Codemagic)

#### Create Separate Workflows
```yaml
# codemagic.yaml
workflows:
  # Production v1.0 (existing)
  production-v1:
    name: Production v1.0
    triggering:
      events:
        - push
      branch_patterns:
        - pattern: 'main'
    scripts:
      - flutter build apk --release
    # ... existing config ...
  
  # Beta v2.0 (new)
  beta-v2:
    name: Beta v2.0
    triggering:
      events:
        - push
      branch_patterns:
        - pattern: 'develop-v2'
    scripts:
      - flutter build apk --release \
          --dart-define=ENABLE_SERENDIPITY=true \
          --dart-define=ENABLE_PROXIMITY_ALERTS=true \
          --dart-define=SUPABASE_URL=$V2_SUPABASE_URL \
          --dart-define=SUPABASE_ANON_KEY=$V2_SUPABASE_KEY
    artifacts:
      - build/app/outputs/apk/release/app-release.apk
    publishing:
      # Upload to separate TestFlight/Play Store track
      app_store_connect:
        track: beta # NOT production
```

---

### Phase 6: User Segmentation

#### Beta Testing Group
```sql
-- Add column to profiles
ALTER TABLE profiles ADD COLUMN beta_tester BOOLEAN DEFAULT FALSE;

-- Mark beta users
UPDATE profiles SET beta_tester = TRUE WHERE email IN (
  'tester1@example.com',
  'tester2@example.com'
);
```

#### App-Side Check
```dart
// lib/main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if user is beta tester
  final user = await Supabase.instance.client.auth.getUser();
  final profile = await Supabase.instance.client
    .from('profiles')
    .select('beta_tester')
    .eq('id', user.id)
    .single();
  
  // Enable features for beta testers
  if (profile['beta_tester'] == true) {
    // Override feature flags
    FeatureFlags.enableSerendipityMode = true;
  }
  
  runApp(MyApp());
}
```

---

## Recommended Timeline

### Week 1-2: Setup
- [ ] Create `develop-v2` branch
- [ ] Set up feature flag system
- [ ] Create separate Supabase dev project
- [ ] Configure Codemagic for beta builds

### Week 3-8: Development
- [ ] Build Serendipity features on `develop-v2`
- [ ] Test with dev Supabase project
- [ ] Keep `main` branch stable (production v1.0)

### Week 9-10: Beta Testing
- [ ] Deploy beta build to TestFlight/Play Store Beta track
- [ ] Invite 50-100 beta testers
- [ ] Collect feedback

### Week 11-12: Gradual Rollout
- [ ] Enable features for 10% of production users (via feature flags)
- [ ] Monitor metrics
- [ ] Gradually increase to 50%, then 100%

### Week 13: Full Launch
- [ ] Merge `develop-v2` → `main`
- [ ] Enable all features for all users
- [ ] Migrate all users to v2.0 Supabase project (if needed)

---

## Risk Mitigation

### Rollback Plan
```dart
// Kill switch - disable all v2 features remotely
class RemoteConfig {
  static Future<bool> shouldEnableSerendipity() async {
    final response = await Supabase.instance.client
      .from('app_config')
      .select('serendipity_enabled')
      .single();
    
    return response['serendipity_enabled'] ?? false;
  }
}
```

### Monitoring
- Set up Sentry/Firebase Crashlytics for both versions
- Track feature flag usage in analytics
- Monitor Supabase database performance

---

## Final Recommendation

**Use Option A (Same Repo + Feature Flags)** because:
1. ✅ Easier to maintain
2. ✅ Gradual rollout capability
3. ✅ Can A/B test features
4. ✅ Bug fixes automatically available to both versions
5. ✅ Single CI/CD pipeline

**Next Steps**:
1. Create `develop-v2` branch
2. Implement feature flag system
3. Create dev Supabase project
4. Start building Serendipity Engine features

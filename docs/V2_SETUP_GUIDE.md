# Nerd Herd V2 Repository Setup Guide

## Step 1: Create GitHub Repository (Manual)

Since GitHub CLI is not installed, we'll do this through the GitHub website:

### 1.1 Create Repository on GitHub
1. Go to https://github.com/new
2. Fill in:
   - **Repository name**: `nerd-herd-v2`
   - **Description**: `Nerd Herd 2.0 - AI-powered campus social network with Serendipity Engine`
   - **Visibility**: Private ✅
   - **Initialize**: ❌ Do NOT initialize with README (we'll add our own)
3. Click "Create repository"

### 1.2 Note Your Repository URL
After creation, you'll see:
```
https://github.com/YOUR-USERNAME/nerd-herd-v2.git
```
**Save this URL** - you'll need it in the next steps.

---

## Step 2: Create Local Directory

Run these commands in PowerShell:

```powershell
# Navigate to your projects folder
cd C:\Users\Husse\Documents

# Create new directory for v2
mkdir nerd-herd-v2
cd nerd-herd-v2

# Initialize git
git init
git branch -M main
```

---

## Step 3: Copy Essential Files from V1

### Option A: Start Fresh (Recommended)
Copy only the core files you need:

```powershell
# Copy essential configuration
Copy-Item ..\Anti\pubspec.yaml .
Copy-Item ..\Anti\analysis_options.yaml .
Copy-Item ..\Anti\.gitignore .

# Copy models (shared data structures)
New-Item -ItemType Directory -Path lib\models
Copy-Item ..\Anti\lib\models\*.dart lib\models\

# Copy config
New-Item -ItemType Directory -Path lib\config
Copy-Item ..\Anti\lib\config\*.dart lib\config\

# Copy assets
Copy-Item -Recurse ..\Anti\assets .

# Create basic structure
New-Item -ItemType Directory -Path lib\pages
New-Item -ItemType Directory -Path lib\widgets
New-Item -ItemType Directory -Path lib\services
```

### Option B: Fork Everything (Alternative)
Copy the entire v1 codebase:

```powershell
# Copy everything except git history
Copy-Item -Recurse ..\Anti\* . -Exclude .git,build,.dart_tool,node_modules
```

---

## Step 4: Update pubspec.yaml

Edit `pubspec.yaml` to reflect v2:

```yaml
name: nerd_herd_v2
description: Nerd Herd 2.0 with AI-powered Serendipity Engine
version: 2.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # Existing dependencies from v1
  supabase_flutter: ^2.0.0
  geolocator: ^10.1.0
  # ... (keep all existing dependencies)
  
  # NEW: AI/ML dependencies for Serendipity Engine
  http: ^1.1.0  # For calling Gemini API
  vector_math: ^2.1.4  # For similarity calculations

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

---

## Step 5: Create README.md

```powershell
# Create README
New-Item -ItemType File -Path README.md
```

Add this content to `README.md`:

```markdown
# Nerd Herd 2.0 🧠

AI-powered campus social network with the **Serendipity Engine** - manufacturing lucky academic collisions.

## What's New in V2.0

### The Serendipity Engine
- **Contextual Proximity Alerts**: Get notified when someone nearby can help with your current struggle
- **Study Constellation**: AI finds 2-3 students with complementary skills for optimal study groups
- **Temporal Pattern Matching**: Connect with peers who have the same "golden hours"

### Technology Stack
- **Frontend**: Flutter 3.x
- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **AI/ML**: Gemini Flash 2.0 for NLP, Collaborative Filtering for matching
- **Real-time**: WebSockets for live proximity alerts

## Development Setup

1. Install Flutter SDK
2. Clone this repository
3. Run `flutter pub get`
4. Set up Supabase project (see docs/SUPABASE_SETUP.md)
5. Run `flutter run`

## Documentation
- [Serendipity Engine Strategy](docs/SERENDIPITY_ENGINE_STRATEGY.md)
- [Implementation Plan](docs/SERENDIPITY_IMPLEMENTATION.md)
- [AI/ML Technical Details](docs/SERENDIPITY_AI_TECHNICAL.md)

## Repository Structure
This is a **separate repository** from Nerd Herd v1.0 to ensure:
- Complete isolation from production
- Freedom to experiment with new architecture
- Clean codebase without feature flag clutter

## License
Proprietary - All Rights Reserved
```

---

## Step 6: Create Initial Commit

```powershell
# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Nerd Herd 2.0 base structure

- Copied essential files from v1.0
- Updated pubspec.yaml for v2.0
- Added Serendipity Engine documentation
- Set up project structure for AI/ML features"

# Link to GitHub (replace YOUR-USERNAME)
git remote add origin https://github.com/YOUR-USERNAME/nerd-herd-v2.git

# Push to GitHub
git push -u origin main
```

---

## Step 7: Set Up New Supabase Project

### 7.1 Create Project
1. Go to https://supabase.com/dashboard
2. Click "New Project"
3. Fill in:
   - **Name**: `nerd-herd-v2-dev`
   - **Database Password**: (generate strong password - SAVE THIS!)
   - **Region**: Choose closest to your users
4. Wait for project to initialize (~2 minutes)

### 7.2 Get Project Credentials
1. Go to Project Settings > API
2. Copy:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **Anon/Public Key**: `eyJhbGc...`

### 7.3 Update .env File

Create `.env` file in project root:

```env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...
GEMINI_API_KEY=your-gemini-api-key-here
```

Add to `.gitignore`:
```
.env
```

### 7.4 Initialize Supabase CLI

```powershell
# Initialize Supabase in project
supabase init

# Link to your new project
supabase link --project-ref your-project-id

# You'll be prompted for the database password you created
```

---

## Step 8: Create Base Database Schema

Create `supabase/migrations/20250101000000_initial_schema.sql`:

```sql
-- Copy base schema from v1.0
-- (profiles, connections, messages, etc.)

-- Then add NEW v2.0 tables
CREATE TABLE struggle_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  topic TEXT,
  confidence_level INT CHECK (confidence_level BETWEEN 1 AND 5),
  location GEOGRAPHY(POINT),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '2 hours'
);

CREATE TABLE compatibility_scores (
  user_a UUID REFERENCES profiles(id) ON DELETE CASCADE,
  user_b UUID REFERENCES profiles(id) ON DELETE CASCADE,
  score FLOAT CHECK (score BETWEEN 0 AND 1),
  factors JSONB,
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_a, user_b)
);

CREATE TABLE serendipity_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a UUID REFERENCES profiles(id) ON DELETE CASCADE,
  user_b UUID REFERENCES profiles(id) ON DELETE CASCADE,
  match_type TEXT,
  accepted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE struggle_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE compatibility_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE serendipity_matches ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own struggle signals"
  ON struggle_signals FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own struggle signals"
  ON struggle_signals FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

Apply migration:
```powershell
supabase db push
```

---

## Step 9: Update Supabase Config in Code

Edit `lib/config/supabase_config.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
    
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }
}
```

---

## Step 10: Test the Setup

```powershell
# Get dependencies
flutter pub get

# Run the app
flutter run
```

You should see the app launch with the base v1.0 functionality. Now you're ready to start adding Serendipity Engine features!

---

## Next Steps

1. ✅ Repository created and pushed to GitHub
2. ✅ Supabase project set up
3. ✅ Base schema migrated
4. 🔄 Start implementing Serendipity features:
   - [ ] Struggle signal UI
   - [ ] Proximity matcher Edge Function
   - [ ] Study Constellation algorithm
   - [ ] Temporal pattern analysis

---

## Troubleshooting

### "Supabase command not found"
Install Supabase CLI:
```powershell
scoop install supabase
```

### "Flutter not found"
Ensure Flutter is in your PATH. Run:
```powershell
flutter doctor
```

### Git authentication issues
Set up SSH keys or use GitHub Desktop for easier authentication.

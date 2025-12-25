# Implementation Plan: The Serendipity Engine

## Goal Description
Build the core "Serendipity Engine" features that create AI-orchestrated academic collisions between students. This focuses on three key capabilities: Contextual Proximity Alerts, Study Constellation matching, and Temporal Pattern detection.

## User Review Required
> [!WARNING]
> **Battery Impact**: Continuous location tracking and real-time matching will impact battery life. We need aggressive optimization and user controls.
> **Privacy Sensitivity**: Sharing "struggle signals" requires explicit opt-in and transparent controls.

> [!IMPORTANT]
> **ML Infrastructure**: This requires vector embeddings and graph neural networks. Consider using managed services (Supabase pgvector + external ML API) vs. building in-house.

---

## Phase 1: Foundation (Weeks 1-3)

### Database Schema
#### [NEW] `database/serendipity_core.sql`
```sql
-- User struggle signals
CREATE TABLE struggle_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  subject TEXT NOT NULL,
  topic TEXT,
  confidence_level INT CHECK (confidence_level BETWEEN 1 AND 5),
  location GEOGRAPHY(POINT),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '2 hours'
);

-- Compatibility matrix (pre-computed)
CREATE TABLE compatibility_scores (
  user_a UUID REFERENCES profiles(id),
  user_b UUID REFERENCES profiles(id),
  score FLOAT CHECK (score BETWEEN 0 AND 1),
  factors JSONB, -- breakdown: skill_complement, temporal_overlap, etc.
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_a, user_b)
);

-- Serendipity matches (successful alerts)
CREATE TABLE serendipity_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a UUID REFERENCES profiles(id),
  user_b UUID REFERENCES profiles(id),
  match_type TEXT, -- 'proximity', 'constellation', 'temporal'
  accepted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User preferences
ALTER TABLE profiles ADD COLUMN serendipity_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN serendipity_radius_meters INT DEFAULT 100;
```

#### [NEW] `database/serendipity_rls.sql`
- RLS policies for `struggle_signals` (users can only see their own).
- RLS for `serendipity_matches` (only involved parties).

---

## Phase 2: Struggle Detection (Weeks 4-5)

### UI Components
#### [NEW] `lib/pages/serendipity/struggle_status_widget.dart`
- Floating action button on map: "What are you working on?"
- Quick-select chips: subjects from user's courses.
- Confidence slider: "How stuck are you? (1-5)"
- Auto-expires after 2 hours.

#### [MODIFY] `lib/pages/map_section/map_page.dart`
- Add "Serendipity Mode" toggle in settings.
- When enabled, periodically update `struggle_signals` with current location.

### Backend
#### [NEW] `supabase/functions/detect-struggle/index.ts`
- **Trigger**: Webhook from chat messages containing keywords ("stuck", "confused", "help").
- **Action**: Auto-creates `struggle_signal` entry.
- **Privacy**: Only triggers if user has serendipity enabled.

---

## Phase 3: Proximity Alerts (Weeks 6-7)

### Edge Functions
#### [NEW] `supabase/functions/proximity-matcher/index.ts`
- **Trigger**: Cron job every 5 minutes.
- **Logic**:
  1. Find all active `struggle_signals` (not expired).
  2. For each signal, query nearby users (within radius) who have complementary signals.
  3. Create `serendipity_matches` entries.
  4. Send push notifications to both parties.

**Complementary Logic**:
- User A struggling with "Calculus Integration" + User B recently solved similar (detected from chat history or past signals).

### UI Components
#### [NEW] `lib/pages/serendipity/proximity_alert_dialog.dart`
- Modal: "Someone nearby can help with [subject]! Say hi?"
- Actions: "Connect", "Not now", "Disable alerts for 1 hour".

---

## Phase 4: Study Constellation (Weeks 8-10)

### AI/ML Integration
#### [NEW] `supabase/functions/compute-compatibility/index.ts`
- **Trigger**: Cron job nightly (or on-demand for active users).
- **Input**: User skill matrix (from courses, reviews, past tutoring).
- **Processing**:
  - Use collaborative filtering to find complementary skill gaps.
  - Graph analysis: Who would benefit from connecting?
- **Output**: Updates `compatibility_scores` table.

**External Service**: Consider using OpenAI Embeddings or Gemini for skill vectorization.

### UI Components
#### [NEW] `lib/pages/serendipity/constellation_page.dart`
- "Recommended Study Groups" section.
- Shows 2-3 person groups with compatibility breakdown.
- Visual: Network graph showing skill overlap.

---

## Phase 5: Temporal Patterns (Weeks 11-12)

### Analytics
#### [NEW] `database/user_activity_patterns.sql`
```sql
-- Track app usage patterns
CREATE TABLE activity_logs (
  user_id UUID REFERENCES profiles(id),
  event_type TEXT, -- 'app_open', 'study_session_start', etc.
  timestamp TIMESTAMPTZ DEFAULT NOW()
);
```

#### [NEW] `supabase/functions/analyze-temporal-patterns/index.ts`
- **Trigger**: Weekly batch job.
- **Logic**: 
  - Analyze `activity_logs` to find user's "golden hours".
  - Store in `profiles.productivity_hours` (JSONB).
- **Matching**: Find users with overlapping productive hours + same courses.

---

## Phase 6: Feedback Loop (Week 13)

### UI Components
#### [MODIFY] `lib/pages/serendipity/proximity_alert_dialog.dart`
- After connection: "How was this match? (1-5 stars)"
- Feedback stored in `serendipity_matches.rating`.

### ML Improvement
- Use match ratings to retrain compatibility algorithm.
- Low-rated matches → adjust weighting factors.

---

## Verification Plan

### Automated Tests
1. **Unit Test**: `proximity-matcher` logic with mock data (2 users, complementary signals, within radius).
2. **Integration Test**: End-to-end flow from struggle signal creation → proximity alert → connection.

### Manual Verification
1. **Scenario 1**: Create 2 test users at same location with complementary struggles → Verify alert sent.
2. **Scenario 2**: Test "Study Constellation" with 3 users having different skill profiles → Verify group recommendation.
3. **Scenario 3**: Simulate week of activity for temporal pattern detection → Verify "golden hours" calculated correctly.

### Performance Testing
- **Load**: 10,000 active users with struggle signals → Verify cron job completes in <30 seconds.
- **Battery**: Monitor battery drain with serendipity mode enabled for 8 hours.

---

## Rollout Strategy

### Beta (Week 14)
- Enable for 100 opt-in users at single campus.
- Collect feedback on alert frequency, match quality.

### Campus Launch (Week 16)
- Full rollout at pilot university.
- Target: 20% adoption rate within first month.

### Iteration (Weeks 17-20)
- Tune matching algorithms based on feedback.
- Add features: "Serendipity Stories" sharing, leaderboards.

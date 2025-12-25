# Implementation Plan: IP & "Secret Sauce" Features

## Goal Description
Implement the "Proof-of-Competence" (PoC) protocol and "Nexus Profile" to operationalize the "Secret Sauce" IP strategy. This focuses on capturing, analyzing, and visualizing informal learning data.

## User Review Required
> [!WARNING]
> **Data Privacy**: Analyzing chat logs for "competence" requires strict privacy controls. We must ensure only *anonymized* or *local* processing, or obtain explicit user consent ("Opt-in to earn Competence Badges").
> **Battery Usage**: Continuous location tracking for "Deep Work" verification is battery-intensive.

---

## 1. "Deep Work" Oracle (Location & Behavior) 🧘‍♂️
*Verify study hours to distinguish "hanging out" from "working".*

### Database Changes
#### [NEW] `database/ip_tracking.sql`
- **Table**: `verified_sessions`
  - `session_id` (UUID)
  - `user_id` (FK)
  - `spot_id` (FK)
  - `start_time`, `end_time`
  - `focus_score` (0-100, derived from screen time/movement if accessible, or just time-at-location)

### Edge Functions
#### [NEW] `supabase/functions/verify-session/index.ts`
- **Trigger**: Client-side "End Session" or geofence exit.
- **Logic**:
  - Validates GPS ping history against Spot polygon.
  - Checks duration > 30 mins.
  - Awards "Focus Points" to user profile.

### UI Components
#### [MODIFY] `lib/pages/map_section/spot_details_sheet.dart`
- **Feature**: "Check-in for Focus Mode" button.
- **UI**: Timer overlay showing "Verifying Session...".

---

## 2. "Competence Score" Analysis (NLP) 🧠
*Turn chat help into verified skills.*

### Backend / AI
#### [NEW] `supabase/functions/analyze-interaction/index.ts`
- **Trigger**: Post-session review or "Thank you" detection in chat.
- **Input**: Last 50 messages of a conversation.
- **Prompt**: "Analyze the following explanation given by User A. Score it on Clarity (1-5), Empathy (1-5), and Socratic Method (Yes/No)."
- **Output**: Updates `user_skills` table.

### Database Changes
#### [NEW] `database/ip_skills.sql`
- **Table**: `user_skills`
  - `user_id`
  - `skill_tag` (e.g., "Calculus", "Python")
  - `competence_score` (Aggregate float)
  - `endorsement_count` (Integer)

---

## 3. The "Nexus Profile" (Visualization) 🆔
*Display the data recruiters want.*

### UI Components
#### [NEW] `lib/pages/profile/nexus_profile_page.dart`
- **Design**: A futuristic, detailed resume alternatives.
- **Components**:
  - **Radar Chart**: Visualizes Soft Skills (Punctuality, Clarity, Empathy).
  - **"Impact Map"**: Visualization of people you've helped (nodes connecting to other nodes).
  - **"Hours Logged"**: Stat pills showing `verified_sessions` aggregates (e.g., "120 Hrs @ Libraries").

#### [MODIFY] `lib/pages/profile/glass_profile_drawer.dart`
- Add "View Nexus Profile" button (Premium feature or Public toggle).

---

## 4. Recursive Authority (The Network Effect) 🕸️
*If the person you taught teaches someone else, you get credit.*

### Database Changes
#### [NEW] `database/ip_graph.sql`
- **Table**: `knowledge_lineage`
  - `ancestor_user_id` (The original teacher)
  - `descendant_user_id` (The student who became a teacher)
  - `skill_tag`
  - `generation_depth` (1, 2, 3...)

### Edge Functions
#### [NEW] `supabase/functions/update-authority/index.ts`
- **Trigger**: When a user's `competence_score` increases significantly.
- **Logic**:
  - Find `verified_sessions` where this user was a *Student*.
  - specific Tutors in those sessions get a localized "Teacher Bonus" to their authority score.

## Verification Plan
1.  **Simulate Session**: Use `mock_location_provider` to simulate a 1-hour stay at a library -> Verify `verified_sessions` entry created.
2.  **Test NLP**: Feed a transcript of a good explanation into `analyze-interaction` -> Verify `competence_score` increases.
3.  **UI Check**: Ensure the "Radar Chart" correctly renders test data on the Nexus Profile.

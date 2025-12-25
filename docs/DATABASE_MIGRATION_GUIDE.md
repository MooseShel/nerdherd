# Database Migration Guide: V1 → V2

## Overview
You need to copy your existing v1.0 database schema to the new v2 Supabase project, then add the new Serendipity Engine tables.

---

## Option 1: Manual Copy (Easiest)

### Step 1: Export V1 Schema
1. Go to your **v1.0 Supabase project** dashboard
2. Navigate to **SQL Editor**
3. Run this query to see all your tables:
```sql
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public';
```

### Step 2: Copy Each Table Definition
For each table (profiles, connections, messages, etc.), get the CREATE statement:

1. In v1 Supabase → **Table Editor**
2. Click on a table (e.g., `profiles`)
3. Click the **"..."** menu → **"View SQL"**
4. Copy the CREATE TABLE statement

### Step 3: Paste into V2 Project
1. Go to your **v2 Supabase project** (nerd-herd-v2-dev)
2. **SQL Editor** → New query
3. Paste all the CREATE TABLE statements
4. Click **Run**

### Step 4: Add Serendipity Tables
Now run the clean schema file:
- Open: `C:\Users\Husse\Documents\Anti\database\v2_serendipity_clean.sql`
- Copy all contents
- Paste in v2 SQL Editor
- Run

---

## Option 2: Use Existing SQL Files (Faster)

If you have SQL migration files in your v1 project:

### Step 1: Find Your Migration Files
Look in your v1 project:
```
C:\Users\Husse\Documents\Anti\database\
```

You should have files like:
- `profiles.sql`
- `connections.sql`
- `messages.sql`
- `appointments.sql`
- etc.

### Step 2: Run Them in Order
In your **v2 Supabase SQL Editor**, run each file in this order:

1. **Core tables first**:
```sql
-- Run contents of profiles.sql
-- Run contents of universities.sql
-- Run contents of courses.sql
```

2. **Relationship tables**:
```sql
-- Run contents of connections.sql
-- Run contents of messages.sql
-- Run contents of appointments.sql
```

3. **Feature tables**:
```sql
-- Run contents of reviews.sql
-- Run contents of spots.sql
-- Run contents of wallet_transactions.sql
```

4. **Finally, Serendipity tables**:
```sql
-- Run v2_serendipity_clean.sql
```

---

## Option 3: Automated Migration (Advanced)

If Supabase CLI is set up:

```powershell
# Export from v1 (production)
supabase db dump --db-url "postgresql://postgres:[PASSWORD]@[V1-PROJECT-URL]:5432/postgres" > v1_schema.sql

# Import to v2 (dev)
psql "postgresql://postgres:[PASSWORD]@[V2-PROJECT-URL]:5432/postgres" < v1_schema.sql

# Then add Serendipity tables
psql "postgresql://postgres:[PASSWORD]@[V2-PROJECT-URL]:5432/postgres" < database/v2_serendipity_clean.sql
```

---

## Recommended Approach

**Use Option 2** if you have the SQL files in your `database/` folder.

### Quick Checklist:
- [ ] Run all existing v1 SQL files in v2 project
- [ ] Verify tables created (check Table Editor)
- [ ] Run `v2_serendipity_clean.sql`
- [ ] Done!

---

## What Tables Should You Have After Migration?

### From V1 (Existing):
- `profiles`
- `universities`
- `courses`
- `user_courses`
- `connections`
- `messages`
- `conversations`
- `appointments`
- `reviews`
- `spots`
- `wallet_transactions`
- `notifications`

### New in V2 (Serendipity):
- `struggle_signals`
- `compatibility_scores`
- `serendipity_matches`
- `activity_logs`
- `user_skills`

---

## Troubleshooting

### "Table already exists"
Skip that table, it's already created.

### "Column already exists" 
The ALTER TABLE commands have `IF NOT EXISTS`, so they're safe to re-run.

### "Foreign key constraint fails"
Run tables in the right order (parent tables before child tables).

---

Need help? Let me know which option you want to use!

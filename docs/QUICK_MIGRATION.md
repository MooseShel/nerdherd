# Quick Database Migration Steps

## Step 1: Run Base Schema
1. Open `C:\Users\Husse\Documents\Anti\database\schema.sql`
2. Copy all contents
3. Go to v2 Supabase → SQL Editor
4. Paste and Run

## Step 2: Run These Files in Order
Copy and run each file in your v2 Supabase SQL Editor:

```
1. create_connections_table.sql
2. create_messages_table.sql
3. create_appointments.sql
4. create_reviews_table.sql
5. create_study_spots.sql
6. create_notifications.sql
7. payment_schema.sql
8. monetization_schema.sql
9. admin_safety_support.sql
```

## Step 3: Add Serendipity Tables
Finally, run:
```
v2_serendipity_clean.sql
```

## Done!
Your v2 database now has everything from v1 PLUS the new Serendipity Engine tables.

# Database Migration Guide

This guide will help you apply the database migrations to your Supabase project.

## Prerequisites
- Access to your Supabase project dashboard
- SQL Editor access

## Migrations to Apply

### 1. Enhanced Chat Migration
**File**: `database/enhance_chat.sql`

**What it does**:
- Creates `typing_status` table for real-time typing indicators
- Adds columns to `messages` table: `delivered_at`, `message_type`, `media_url`
- Creates `chat-images` storage bucket
- Sets up RLS policies for chat images

**To apply**:
1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `enhance_chat.sql`
3. Paste and run
4. Verify: Check that `typing_status` table exists

### 2. Notifications Migration
**File**: `database/create_notifications.sql`

**What it does**:
- Creates `notifications` table
- Creates `create_notification()` helper function
- Sets up triggers for:
  - New collaboration requests
  - New messages
  - Request accepted
- Creates performance indexes

**To apply**:
1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `create_notifications.sql`
3. Paste and run
4. Verify: Check that `notifications` table exists and triggers are created

## Verification Steps

### Check Tables
```sql
-- Verify typing_status table
SELECT * FROM typing_status LIMIT 1;

-- Verify notifications table
SELECT * FROM notifications LIMIT 1;

-- Verify messages columns
SELECT message_type, media_url, delivered_at FROM messages LIMIT 1;
```

### Check Storage Bucket
1. Go to Storage in Supabase Dashboard
2. Verify `chat-images` bucket exists
3. Check policies are set

### Check Triggers
```sql
-- List all triggers
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_schema = 'public';
```

You should see:
- `trigger_notify_new_request` on `collab_requests`
- `trigger_notify_new_message` on `messages`
- `trigger_notify_request_accepted` on `collab_requests`

## Troubleshooting

### Error: "relation already exists"
- Tables may already exist from a previous migration
- Use `DROP TABLE IF EXISTS` before creating, or skip that part

### Error: "function already exists"
- Functions may already exist
- Use `CREATE OR REPLACE FUNCTION` (already in the SQL)

### Storage bucket error
- Bucket may already exist
- The SQL uses `ON CONFLICT DO NOTHING` so it should be safe

## Testing After Migration

1. **Test Typing Status**:
   ```sql
   INSERT INTO typing_status (user_id, chat_with, is_typing)
   VALUES ('your-user-id', 'other-user-id', true);
   ```

2. **Test Notification Creation**:
   ```sql
   -- This should auto-create a notification via trigger
   INSERT INTO collab_requests (sender_id, receiver_id, status)
   VALUES ('sender-id', 'receiver-id', 'pending');
   
   -- Check notification was created
   SELECT * FROM notifications WHERE user_id = 'receiver-id';
   ```

3. **Test Image Upload**:
   - Use the app to upload a chat image
   - Verify it appears in `chat-images` bucket
   - Check RLS policies allow access

## Rollback (if needed)

If you need to undo the migrations:

```sql
-- Drop notifications system
DROP TRIGGER IF EXISTS trigger_notify_new_request ON collab_requests;
DROP TRIGGER IF EXISTS trigger_notify_new_message ON messages;
DROP TRIGGER IF EXISTS trigger_notify_request_accepted ON collab_requests;
DROP FUNCTION IF EXISTS notify_new_request();
DROP FUNCTION IF EXISTS notify_new_message();
DROP FUNCTION IF EXISTS notify_request_accepted();
DROP FUNCTION IF EXISTS create_notification(UUID, TEXT, TEXT, TEXT, JSONB);
DROP TABLE IF EXISTS notifications;

-- Drop typing status
DROP TABLE IF EXISTS typing_status;

-- Remove message columns (optional, may break existing data)
ALTER TABLE messages DROP COLUMN IF EXISTS delivered_at;
ALTER TABLE messages DROP COLUMN IF EXISTS message_type;
ALTER TABLE messages DROP COLUMN IF EXISTS media_url;
```

## Next Steps After Migration

1. Run the Flutter app
2. Test each feature:
   - Send a collaboration request
   - Send a chat message
   - Upload an image in chat
   - Check notifications appear
3. Monitor Supabase logs for any errors

### 3. Admin Portal Migration
**Files**:
- `database/add_admin_columns.sql`
- `database/admin_policies.sql`

**What it does**:
- Adds `is_admin` and `is_banned` columns to `profiles` table.
- Enables RLS policies for admins to manage all profiles.

**To apply**:
1. Open Supabase Dashboard → SQL Editor
2. Run contents of `add_admin_columns.sql`.
3. Run contents of `admin_policies.sql`.
4. **Important**: Grant yourself admin access:
   ```sql
   UPDATE public.profiles SET is_admin = true WHERE user_id = auth.uid();
   ```

### 4. Payment Integration Migration
**File**: `database/payment_schema.sql`

**What it does**:
- Adds `wallet_balance` column to `profiles`.
- Creates `transactions` table with RLS policies.

**To apply**:
1. Open Supabase Dashboard → SQL Editor
2. Run contents of `payment_schema.sql`.
3. Run contents of `enable_realtime_transactions.sql` (Required for transaction list updates).
4. Run contents of `alter_appointments_payment.sql` (Adds price/paid columns).
5. Run contents of `create_payment_rpc.sql` (Secure payment function).
6. Run contents of `fix_transaction_types.sql` (Transaction types constraint).
7. Run contents of `fix_reviews_rls.sql` (Allow reviewing completed appointments).
8. Verify: Check `wallet_balance` column in `profiles` and new `transactions` table.

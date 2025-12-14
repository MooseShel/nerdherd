# Notification Foreign Key Error - Fix

## Problem
```
PostgrestException: insert or update on table "notifications" violates foreign key constraint "notifications_user_id_fkey"
Key (user_id)=(00000000-0000-4000-b000-000000000002) is not present in table "users"
```

## Root Cause
The notification triggers were trying to create notifications for simulated/test users that exist in the `profiles` table but not in the `auth.users` table.

## Solution
Updated all notification triggers to check if the user exists in `auth.users` before creating a notification.

### Changes Made

#### 1. Updated `create_notification()` Function
Added user existence check:
```sql
SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id) INTO user_exists;

IF user_exists THEN
  -- Create notification
ELSE
  -- Skip notification creation
  RETURN NULL;
END IF;
```

#### 2. Updated All Triggers
Added existence checks in:
- `notify_new_request()` - Checks if receiver exists
- `notify_new_message()` - Checks if receiver exists  
- `notify_request_accepted()` - Checks if sender exists

## How to Apply the Fix

### Option 1: Re-run the Migration
1. Drop existing triggers and functions:
```sql
DROP TRIGGER IF EXISTS trigger_notify_new_request ON collab_requests;
DROP TRIGGER IF EXISTS trigger_notify_new_message ON messages;
DROP TRIGGER IF EXISTS trigger_notify_request_accepted ON collab_requests;
DROP FUNCTION IF EXISTS notify_new_request();
DROP FUNCTION IF EXISTS notify_new_message();
DROP FUNCTION IF EXISTS notify_request_accepted();
DROP FUNCTION IF EXISTS create_notification(UUID, TEXT, TEXT, TEXT, JSONB);
```

2. Run the updated `create_notifications.sql`

### Option 2: Update Functions Only
Just run the updated function definitions from `create_notifications.sql`. The `CREATE OR REPLACE FUNCTION` statements will update the existing functions.

## Testing
After applying the fix, test with simulated users:
```sql
-- This should now work without error
INSERT INTO collab_requests (sender_id, receiver_id, status)
VALUES ('simulated-user-id', 'real-user-id', 'pending');
```

The trigger will:
- ✅ Create notification if receiver is in `auth.users`
- ✅ Skip notification if receiver is only in `profiles` (simulated user)

## Prevention
This fix allows the app to work with:
- Real authenticated users (notifications work)
- Simulated test users (notifications skipped gracefully)
- Mixed environments (development/testing)

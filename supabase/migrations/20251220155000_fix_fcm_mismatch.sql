-- 1. Create a secure RPC function to update FCM token
-- This bypasses complex RLS checks for simple token updates and ensures the user only updates their OWN token.
create or replace function public.update_fcm_token(token text)
returns void as $$
begin
  update public.profiles
  set fcm_token = token,
      updated_at = now()
  where user_id = auth.uid(); -- Enforces security: only the caller's row is updated
end;
$$ language plpgsql security definer;

-- 2. Ensure RLS Policy allows UPDATE (Just in case the RPC isn't used or for general robustness)
-- We attempt to drop the policy first to avoid conflicts, assuming a common name.
-- If the name is different, this might print a notice but won't fail if we use 'if exists'.
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Enable update for users based on user_id" on public.profiles;

create policy "Users can update own profile"
on public.profiles
for update
using (auth.uid() = user_id);

-- 3. Grant execute permission to authenticated users (Critical for RPC)
grant execute on function public.update_fcm_token(text) to authenticated;

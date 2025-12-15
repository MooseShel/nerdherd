-- Enable Realtime for transactions table
-- This is often required for new tables to trigger stream updates in Flutter

BEGIN;
  -- Try to add the table to the publication. 
  -- This might fail if the publication doesn't exist (unlikely in Supabase) or if already added.
  -- We wrap in a block to handle potential errors or just run the command.
  
  ALTER PUBLICATION supabase_realtime ADD TABLE transactions;
  
COMMIT;

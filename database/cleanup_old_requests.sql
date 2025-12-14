-- Clean up old requests that have corresponding connections
-- This removes requests where a connection already exists between the two users

DELETE FROM public.collab_requests
WHERE EXISTS (
    SELECT 1 
    FROM public.connections
    WHERE 
        (connections.user_id_1 = collab_requests.sender_id AND connections.user_id_2 = collab_requests.receiver_id)
        OR
        (connections.user_id_1 = collab_requests.receiver_id AND connections.user_id_2 = collab_requests.sender_id)
);

-- Optional: Also clean up rejected requests older than 7 days
-- DELETE FROM public.collab_requests
-- WHERE status = 'rejected' 
-- AND created_at < NOW() - INTERVAL '7 days';

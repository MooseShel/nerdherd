-- Create RPC function to fetch conversation history
-- Returns one row per conversation partner, with the latest message.

CREATE OR REPLACE FUNCTION get_conversations()
RETURNS TABLE (
    other_user_id UUID,
    full_name TEXT,
    avatar_url TEXT,
    is_tutor BOOLEAN,
    last_message TEXT,
    last_message_time TIMESTAMPTZ,
    unread_count BIGINT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    my_id UUID := auth.uid();
BEGIN
    RETURN QUERY
    WITH latest_messages AS (
        SELECT DISTINCT ON (peer_id)
            CASE WHEN sender_id = my_id THEN receiver_id ELSE sender_id END AS peer_id,
            content,
            created_at,
            sender_id,
            read_at
        FROM messages
        WHERE sender_id = my_id OR receiver_id = my_id
        ORDER BY peer_id, created_at DESC
    ),
    unread_counts AS (
        SELECT
            sender_id AS peer_id,
            COUNT(*) AS cnt
        FROM messages
        WHERE receiver_id = my_id AND read_at IS NULL
        GROUP BY sender_id
    )
    SELECT
        p.user_id AS other_user_id,
        COALESCE(p.full_name, p.intent_tag, 'User') AS full_name,
        p.avatar_url,
        p.is_tutor,
        lm.content AS last_message,
        lm.created_at AS last_message_time,
        COALESCE(uc.cnt, 0) AS unread_count
    FROM latest_messages lm
    JOIN profiles p ON p.user_id = lm.peer_id
    LEFT JOIN unread_counts uc ON uc.peer_id = lm.peer_id
    ORDER BY lm.created_at DESC;
END;
$$;

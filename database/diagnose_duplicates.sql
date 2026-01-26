-- Diagnose Duplicates in Connections
SELECT * FROM public.connections;

-- Count duplicates
SELECT 
    LEAST(user_id_1, user_id_2) as u1,
    GREATEST(user_id_1, user_id_2) as u2,
    COUNT(*)
FROM public.connections
GROUP BY u1, u2
HAVING COUNT(*) > 1;

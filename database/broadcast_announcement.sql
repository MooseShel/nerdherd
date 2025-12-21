-- Trigger to automatically create a notification for EVERY user when a new announcement is posted
CREATE OR REPLACE FUNCTION public.handle_new_announcement_broadcast()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert a notification for every profile
    INSERT INTO public.notifications (user_id, title, message, type)
    SELECT 
        user_id, 
        '📢 ' || NEW.title, 
        NEW.message, 
        'announcement'
    FROM public.profiles
    WHERE is_banned = FALSE; -- Only send to active users

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger
DROP TRIGGER IF EXISTS trigger_broadcast_announcement ON public.announcements;

CREATE TRIGGER trigger_broadcast_announcement
    AFTER INSERT ON public.announcements
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_announcement_broadcast();

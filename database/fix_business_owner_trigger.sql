-- Update handle_new_user to include is_business_owner
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (
    user_id, 
    full_name, 
    address, 
    is_tutor, 
    is_business_owner, -- NEW
    avatar_url
  )
  VALUES (
    NEW.id, 
    NEW.raw_user_meta_data->>'full_name', 
    NEW.raw_user_meta_data->>'address', 
    (NEW.raw_user_meta_data->>'is_tutor')::boolean,
    (NEW.raw_user_meta_data->>'is_business_owner')::boolean, -- NEW
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

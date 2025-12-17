-- Update University Logos
-- Updates existing universities to use themed logo filenames.

UPDATE public.universities
SET logo_url = 'assets/images/nerd_herd_logo.png'
WHERE name = 'Nerd Herd University';

UPDATE public.universities
SET logo_url = 'assets/images/gotham_logo.png'
WHERE name = 'Gotham City University';

UPDATE public.universities
SET logo_url = 'assets/images/metropolis_logo.png'
WHERE name = 'Metropolis Institute of Tech';

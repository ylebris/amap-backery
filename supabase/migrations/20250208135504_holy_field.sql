/*
  # Update existing users and add missing ones

  This migration safely updates existing users and adds any missing ones.
*/

-- First, update existing users if they exist
UPDATE auth.users
SET
  raw_user_meta_data = jsonb_build_object('first_name', CASE id
    WHEN '11111111-1111-1111-1111-111111111111' THEN 'Admin'
    WHEN '22222222-2222-2222-2222-222222222222' THEN 'Baker'
    WHEN '33333333-3333-3333-3333-333333333333' THEN 'Baker'
    WHEN '44444444-4444-4444-4444-444444444444' THEN 'AMAP1'
    WHEN '55555555-5555-5555-5555-555555555555' THEN 'AMAP2'
    WHEN '66666666-6666-6666-6666-666666666666' THEN 'Member'
    WHEN '77777777-7777-7777-7777-777777777777' THEN 'Member'
  END, 'last_name', CASE id
    WHEN '11111111-1111-1111-1111-111111111111' THEN 'User'
    WHEN '22222222-2222-2222-2222-222222222222' THEN 'One'
    WHEN '33333333-3333-3333-3333-333333333333' THEN 'Two'
    WHEN '44444444-4444-4444-4444-444444444444' THEN 'Admin'
    WHEN '55555555-5555-5555-5555-555555555555' THEN 'Admin'
    WHEN '66666666-6666-6666-6666-666666666666' THEN 'One'
    WHEN '77777777-7777-7777-7777-777777777777' THEN 'Two'
  END)
WHERE id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555',
  '66666666-6666-6666-6666-666666666666',
  '77777777-7777-7777-7777-777777777777'
);

-- Then, insert any missing identities
INSERT INTO auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at,
  provider_id
)
SELECT
  u.id,
  u.id,
  json_build_object('sub', u.id::text, 'email', u.email),
  'email',
  now(),
  now(),
  now(),
  u.email
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM auth.identities i
  WHERE i.user_id = u.id
);
/*
  # Create initial users

  This migration creates the initial users in Supabase auth tables.
*/

-- Insert users into auth.users
INSERT INTO auth.users (
  id,
  instance_id,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  role,
  aud,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change_token_current
) VALUES
  -- Admin
  (
    '11111111-1111-1111-1111-111111111111',
    '00000000-0000-0000-0000-000000000000',
    'admin@exemple.net',
    crypt('admin', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"first_name": "Admin", "last_name": "User"}',
    false,
    'authenticated',
    'authenticated',
    '',
    '',
    '',
    ''
  ),
  -- Baker 1
  (
    '22222222-2222-2222-2222-222222222222',
    '00000000-0000-0000-0000-000000000000',
    'baker1@exemple.net',
    crypt('baker1', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"first_name": "Baker", "last_name": "One"}',
    false,
    'authenticated',
    'authenticated',
    '',
    '',
    '',
    ''
  ),
  -- Baker 2
  (
    '33333333-3333-3333-3333-333333333333',
    '00000000-0000-0000-0000-000000000000',
    'baker2@exemple.net',
    crypt('baker2', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"first_name": "Baker", "last_name": "Two"}',
    false,
    'authenticated',
    'authenticated',
    '',
    '',
    '',
    ''
  ),
  -- AMAP 1
  (
    '44444444-4444-4444-4444-444444444444',
    '00000000-0000-0000-0000-000000000000',
    'amap1@exemple.net',
    crypt('amap1', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"first_name": "AMAP1", "last_name": "Admin"}',
    false,
    'authenticated',
    'authenticated',
    '',
    '',
    '',
    ''
  ),
  -- AMAP 2
  (
    '55555555-5555-5555-5555-555555555555',
    '00000000-0000-0000-0000-000000000000',
    'amap2@exemple.net',
    crypt('amap2', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"first_name": "AMAP2", "last_name": "Admin"}',
    false,
    'authenticated',
    'authenticated',
    '',
    '',
    '',
    ''
  ),
  -- Member 1
  (
    '66666666-6666-6666-6666-666666666666',
    '00000000-0000-0000-0000-000000000000',
    'member1@exemple.net',
    crypt('member1', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"first_name": "Member", "last_name": "One"}',
    false,
    'authenticated',
    'authenticated',
    '',
    '',
    '',
    ''
  ),
  -- Member 2
  (
    '77777777-7777-7777-7777-777777777777',
    '00000000-0000-0000-0000-000000000000',
    'member2@exemple.net',
    crypt('member2', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"first_name": "Member", "last_name": "Two"}',
    false,
    'authenticated',
    'authenticated',
    '',
    '',
    '',
    ''
  );

-- Insert identities
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
  id,
  id,
  json_build_object('sub', id::text, 'email', email),
  'email',
  now(),
  now(),
  now(),
  email
FROM auth.users;
-- Création de l'utilisateur dans auth.users
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
) VALUES (
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
);

-- Création de l'identité
INSERT INTO auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at,
  provider_id
) VALUES (
  '11111111-1111-1111-1111-111111111111',
  '11111111-1111-1111-1111-111111111111',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'email', 'admin@exemple.net'),
  'email',
  now(),
  now(),
  now(),
  'admin@exemple.net'
);

-- Création de l'AMAP
INSERT INTO amaps (
  id,
  name,
  address
) VALUES (
  '88888888-8888-8888-8888-888888888888',
  'AMAP Admin',
  'Administration'
);

-- Attribution du rôle super_admin
INSERT INTO amap_members (
  amap_id,
  user_id,
  role
) VALUES (
  '88888888-8888-8888-8888-888888888888',
  '11111111-1111-1111-1111-111111111111',
  'super_admin'
);
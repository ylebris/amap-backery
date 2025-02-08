/*
  # Create initial users and associations

  1. Users Creation
    - Admin user
    - Two bakers
    - Two AMAP admins
    - Two members
  
  2. AMAP Creation
    - AMAP1
    - AMAP2

  3. Associations
    - Baker1 -> AMAP1
    - Baker2 -> AMAP2
    - MEMBER1 -> AMAP1
    - MEMBER2 -> AMAP2
*/

-- Insert users
INSERT INTO users (id, email, password_hash, first_name, last_name)
VALUES
  -- Admin
  ('11111111-1111-1111-1111-111111111111', 'admin@exemple.net', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Admin', 'User'),
  -- Bakers
  ('22222222-2222-2222-2222-222222222222', 'baker1@exemple.net', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Baker', 'One'),
  ('33333333-3333-3333-3333-333333333333', 'baker2@exemple.net', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Baker', 'Two'),
  -- AMAP Admins
  ('44444444-4444-4444-4444-444444444444', 'amap1@exemple.net', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'AMAP1', 'Admin'),
  ('55555555-5555-5555-5555-555555555555', 'amap2@exemple.net', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'AMAP2', 'Admin'),
  -- Members
  ('66666666-6666-6666-6666-666666666666', 'member1@exemple.net', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Member', 'One'),
  ('77777777-7777-7777-7777-777777777777', 'member2@exemple.net', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Member', 'Two');

-- Insert user roles
INSERT INTO user_roles (user_id, role)
VALUES
  -- Admin
  ('11111111-1111-1111-1111-111111111111', 'admin'),
  -- Bakers
  ('22222222-2222-2222-2222-222222222222', 'baker'),
  ('33333333-3333-3333-3333-333333333333', 'baker');

-- Create AMAPs
INSERT INTO amaps (id, name, address)
VALUES
  ('88888888-8888-8888-8888-888888888888', 'AMAP1', '123 Rue des Lilas'),
  ('99999999-9999-9999-9999-999999999999', 'AMAP2', '456 Avenue des Roses');

-- Create AMAP memberships
INSERT INTO amap_members (amap_id, user_id, role)
VALUES
  -- AMAP1 admin and member
  ('88888888-8888-8888-8888-888888888888', '44444444-4444-4444-4444-444444444444', 'amap_admin'),
  ('88888888-8888-8888-8888-888888888888', '66666666-6666-6666-6666-666666666666', 'member'),
  -- AMAP2 admin and member
  ('99999999-9999-9999-9999-999999999999', '55555555-5555-5555-5555-555555555555', 'amap_admin'),
  ('99999999-9999-9999-9999-999999999999', '77777777-7777-7777-7777-777777777777', 'member');

-- Assign bakers to AMAPs
INSERT INTO amap_baker_assignments (amap_id, baker_id)
VALUES
  -- Baker1 -> AMAP1
  ('88888888-8888-8888-8888-888888888888', '22222222-2222-2222-2222-222222222222'),
  -- Baker2 -> AMAP2
  ('99999999-9999-9999-9999-999999999999', '33333333-3333-3333-3333-333333333333');
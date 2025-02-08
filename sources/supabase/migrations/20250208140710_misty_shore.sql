-- Drop any existing auth functions to avoid conflicts
DROP FUNCTION IF EXISTS auth.email_signup(text, text, jsonb);
DROP FUNCTION IF EXISTS auth.email_signin(text, text);
DROP FUNCTION IF EXISTS auth.generate_jwt(uuid);

-- Create required extensions if they don't exist
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create auth schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS auth;

-- Set search path
SET search_path TO auth, public;

-- Create or replace the signup function
CREATE OR REPLACE FUNCTION auth.email_signup(
  email text,
  password text,
  data jsonb DEFAULT '{}'::jsonb
)
RETURNS json AS $$
DECLARE
  new_user auth.users;
  result json;
BEGIN
  -- Insert new user
  INSERT INTO auth.users (
    email,
    encrypted_password,
    raw_user_meta_data,
    email_confirmed_at,
    created_at,
    updated_at,
    aud,
    role
  )
  VALUES (
    email,
    crypt(password, gen_salt('bf')),
    data,
    now(), -- Auto-confirm for development
    now(),
    now(),
    'authenticated',
    'authenticated'
  )
  RETURNING * INTO new_user;

  -- Create identity
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  )
  VALUES (
    gen_random_uuid()::text,
    new_user.id,
    json_build_object(
      'sub', new_user.id::text,
      'email', email
    ),
    'email',
    now(),
    now(),
    now()
  );

  -- Create session
  INSERT INTO auth.sessions (
    user_id,
    created_at,
    updated_at
  )
  VALUES (
    new_user.id,
    now(),
    now()
  );

  -- Return user data
  result := json_build_object(
    'id', new_user.id,
    'email', new_user.email,
    'role', new_user.role,
    'aud', new_user.aud
  );

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create or replace the signin function
CREATE OR REPLACE FUNCTION auth.email_signin(
  email text,
  password text
)
RETURNS json AS $$
DECLARE
  user_data auth.users;
  result json;
BEGIN
  -- Get user
  SELECT *
  INTO user_data
  FROM auth.users
  WHERE users.email = email_signin.email
  AND users.encrypted_password = crypt(password, users.encrypted_password);

  IF user_data.id IS NULL THEN
    RAISE EXCEPTION 'Invalid email or password';
  END IF;

  -- Update last sign in
  UPDATE auth.users 
  SET 
    last_sign_in_at = now(),
    updated_at = now()
  WHERE id = user_data.id;

  -- Create new session
  INSERT INTO auth.sessions (
    user_id,
    created_at,
    updated_at
  )
  VALUES (
    user_data.id,
    now(),
    now()
  );

  -- Return user data
  result := json_build_object(
    'id', user_data.id,
    'email', user_data.email,
    'role', user_data.role,
    'aud', user_data.aud
  );

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA auth TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO anon, authenticated;

-- Ensure RLS is enabled
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
DROP POLICY IF EXISTS "Users can view their own data" ON auth.users;
CREATE POLICY "Users can view their own data" ON auth.users
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can view their own identities" ON auth.identities;
CREATE POLICY "Users can view their own identities" ON auth.identities
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can view their own sessions" ON auth.sessions;
CREATE POLICY "Users can view their own sessions" ON auth.sessions
  FOR SELECT USING (user_id = auth.uid());
-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS auth.email_signin(text, text);
DROP FUNCTION IF EXISTS auth.email_signup(text, text, jsonb);

-- Create schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS auth;

-- Ensure auth schema is in search_path
ALTER DATABASE postgres SET search_path TO public, auth;

-- Create extension if not exists
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create or replace the signin function
CREATE OR REPLACE FUNCTION auth.email_signin(email text, password text)
RETURNS auth.users AS $$
DECLARE
  user_record auth.users;
  valid_password boolean;
BEGIN
  SELECT *
  INTO user_record
  FROM auth.users
  WHERE auth.users.email = email_signin.email
  AND auth.users.encrypted_password = crypt(password, auth.users.encrypted_password);

  IF user_record.id IS NULL THEN
    RAISE EXCEPTION 'Invalid email or password';
  END IF;

  -- Update last sign in
  UPDATE auth.users 
  SET last_sign_in_at = now()
  WHERE id = user_record.id;

  RETURN user_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create or replace the signup function
CREATE OR REPLACE FUNCTION auth.email_signup(email text, password text, data jsonb DEFAULT NULL)
RETURNS auth.users AS $$
DECLARE
  user_id uuid;
  encrypted_pw text;
BEGIN
  -- Check if email already exists
  IF EXISTS (SELECT 1 FROM auth.users WHERE auth.users.email = email_signup.email) THEN
    RAISE EXCEPTION 'User with this email already exists';
  END IF;

  -- Generate encrypted password
  encrypted_pw := crypt(password, gen_salt('bf'));

  -- Create user
  INSERT INTO auth.users (
    email,
    encrypted_password,
    raw_user_meta_data,
    email_confirmed_at,
    created_at,
    updated_at,
    aud,
    role
  ) VALUES (
    email,
    encrypted_pw,
    COALESCE(data, '{}'::jsonb),
    now(), -- Auto-confirm for now
    now(),
    now(),
    'authenticated',
    'authenticated'
  )
  RETURNING id INTO user_id;

  -- Create identity
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
    user_id,
    user_id,
    json_build_object('sub', user_id::text, 'email', email),
    'email',
    now(),
    now(),
    now(),
    email
  );

  RETURN (SELECT * FROM auth.users WHERE id = user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA auth TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO anon, authenticated;
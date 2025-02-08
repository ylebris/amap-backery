-- Drop all existing auth-related objects to start fresh
DROP SCHEMA IF EXISTS auth CASCADE;
CREATE SCHEMA auth;

-- Create required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Set search path
SET search_path TO auth, public;

-- Create auth tables
CREATE TABLE auth.users (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    instance_id uuid,
    email text UNIQUE,
    encrypted_password text,
    email_confirmed_at timestamptz,
    invited_at timestamptz,
    confirmation_token text,
    confirmation_sent_at timestamptz,
    recovery_token text,
    recovery_sent_at timestamptz,
    email_change_token_new text,
    email_change_token_current text,
    email_change_confirm_status smallint DEFAULT 0,
    last_sign_in_at timestamptz,
    raw_app_meta_data jsonb DEFAULT '{}'::jsonb,
    raw_user_meta_data jsonb DEFAULT '{}'::jsonb,
    is_super_admin boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    phone text,
    phone_confirmed_at timestamptz,
    phone_change text DEFAULT '',
    phone_change_token text DEFAULT '',
    phone_change_sent_at timestamptz,
    email_change text DEFAULT '',
    email_change_sent_at timestamptz,
    banned_until timestamptz,
    reauthentication_token text DEFAULT '',
    reauthentication_sent_at timestamptz,
    is_sso_user boolean DEFAULT false,
    deleted_at timestamptz,
    role text DEFAULT 'authenticated',
    aud text DEFAULT 'authenticated',
    CONSTRAINT users_email_check CHECK (email ~* '^[^@]+@[^@]+\.[^@]+$'::text)
);

CREATE TABLE auth.identities (
    provider_id text,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    id text DEFAULT uuid_generate_v4()::text,
    CONSTRAINT identities_pkey PRIMARY KEY (provider, id)
);

CREATE TABLE auth.sessions (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    factor_id uuid,
    aal text,
    not_after timestamptz
);

-- Create indexes
CREATE INDEX users_instance_id_email_idx ON auth.users (instance_id, email);
CREATE INDEX users_instance_id_idx ON auth.users (instance_id);
CREATE INDEX identities_user_id_idx ON auth.identities (user_id);
CREATE INDEX sessions_user_id_idx ON auth.sessions (user_id);
CREATE INDEX users_email_partial_idx ON auth.users (email) WHERE email IS NOT NULL;

-- Enable RLS
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Public users are viewable by everyone." ON auth.users
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own identities." ON auth.identities
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own identities." ON auth.identities
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own sessions." ON auth.sessions
    FOR SELECT USING (auth.uid() = user_id);

-- Grant permissions
GRANT USAGE ON SCHEMA auth TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO anon, authenticated;

-- Create admin user
INSERT INTO auth.users (
    email,
    encrypted_password,
    email_confirmed_at,
    raw_user_meta_data,
    is_super_admin,
    role
) VALUES (
    'admin@exemple.net',
    crypt('admin', gen_salt('bf')),
    now(),
    '{"first_name": "Admin", "last_name": "User"}'::jsonb,
    true,
    'authenticated'
) ON CONFLICT (email) DO NOTHING;

-- Create identity for admin
INSERT INTO auth.identities (
    provider_id,
    user_id,
    identity_data,
    provider
)
SELECT 
    'admin@exemple.net',
    id,
    jsonb_build_object('sub', id::text, 'email', email),
    'email'
FROM auth.users 
WHERE email = 'admin@exemple.net'
ON CONFLICT DO NOTHING;
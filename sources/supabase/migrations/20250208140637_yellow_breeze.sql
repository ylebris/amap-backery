-- Create required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Ensure auth schema exists
CREATE SCHEMA IF NOT EXISTS auth;

-- Create required auth tables if they don't exist
CREATE TABLE IF NOT EXISTS auth.users (
    id uuid NOT NULL PRIMARY KEY DEFAULT uuid_generate_v4(),
    instance_id uuid,
    email text,
    encrypted_password text,
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token text,
    confirmation_sent_at timestamp with time zone,
    recovery_token text,
    recovery_sent_at timestamp with time zone,
    email_change_token_new text,
    email_change_token_current text,
    email_change_confirm_status smallint DEFAULT 0,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb DEFAULT '{}'::jsonb,
    raw_user_meta_data jsonb DEFAULT '{}'::jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::text,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::text,
    phone_change_token text DEFAULT ''::text,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change text DEFAULT ''::text,
    email_change_sent_at timestamp with time zone,
    banned_until timestamp with time zone,
    reauthentication_token text DEFAULT ''::text,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false,
    deleted_at timestamp with time zone,
    role text DEFAULT 'authenticated'::text,
    aud text DEFAULT 'authenticated'::text,
    CONSTRAINT users_email_check CHECK ((email ~* '^[^@]+@[^@]+\.[^@]+$'::text))
);

CREATE TABLE IF NOT EXISTS auth.identities (
    id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower(identity_data->>'email'::text)) STORED,
    CONSTRAINT identities_pkey PRIMARY KEY (provider, id),
    CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS auth.sessions (
    id uuid NOT NULL PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp with time zone,
    user_agent text,
    ip inet,
    tag text,
    CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Create indexes
CREATE INDEX IF NOT EXISTS users_instance_id_email_idx ON auth.users (instance_id, email);
CREATE INDEX IF NOT EXISTS users_instance_id_idx ON auth.users (instance_id);
CREATE INDEX IF NOT EXISTS identities_user_id_idx ON auth.identities (user_id);
CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON auth.sessions (user_id);
CREATE INDEX IF NOT EXISTS sessions_not_after_idx ON auth.sessions (not_after DESC);
CREATE INDEX IF NOT EXISTS sessions_updated_at_idx ON auth.sessions (updated_at DESC);

-- Set up RLS
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

-- Create policies
DROP POLICY IF EXISTS "Users can view their own data" ON auth.users;
CREATE POLICY "Users can view their own data" ON auth.users
    FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can view their own identities" ON auth.identities;
CREATE POLICY "Users can view their own identities" ON auth.identities
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can view their own sessions" ON auth.sessions;
CREATE POLICY "Users can view their own sessions" ON auth.sessions
    FOR SELECT USING (user_id = auth.uid());

-- Grant permissions
GRANT USAGE ON SCHEMA auth TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO anon, authenticated;
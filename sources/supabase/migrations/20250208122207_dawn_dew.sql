/*
  # Système d'authentification personnalisé

  1. Nouvelles Tables
    - `users`: Stocke les informations des utilisateurs
    - `user_sessions`: Gère les sessions utilisateur
    
  2. Modifications
    - Adaptation des références aux utilisateurs
    - Mise à jour des politiques de sécurité
*/

-- Table des utilisateurs
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  first_name text,
  last_name text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Table des sessions
CREATE TABLE IF NOT EXISTS user_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  token text UNIQUE NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Mise à jour des références dans les tables existantes
ALTER TABLE user_roles
DROP CONSTRAINT IF EXISTS user_roles_user_id_fkey,
ADD CONSTRAINT user_roles_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE amap_members
DROP CONSTRAINT IF EXISTS amap_members_user_id_fkey,
ADD CONSTRAINT amap_members_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE amap_baker_assignments
DROP CONSTRAINT IF EXISTS amap_baker_assignments_baker_id_fkey,
ADD CONSTRAINT amap_baker_assignments_baker_id_fkey 
  FOREIGN KEY (baker_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE ephemeral_orders
DROP CONSTRAINT IF EXISTS ephemeral_orders_user_id_fkey,
ADD CONSTRAINT ephemeral_orders_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- Fonctions d'authentification
CREATE OR REPLACE FUNCTION authenticate_user(p_email text, p_password_hash text)
RETURNS uuid AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT id INTO v_user_id
  FROM users
  WHERE email = p_email AND password_hash = p_password_hash;
  
  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_session(p_user_id uuid)
RETURNS text AS $$
DECLARE
  v_token text;
BEGIN
  v_token := encode(gen_random_bytes(32), 'hex');
  
  INSERT INTO user_sessions (user_id, token, expires_at)
  VALUES (p_user_id, v_token, now() + interval '24 hours');
  
  RETURN v_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION validate_session(p_token text)
RETURNS uuid AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT user_id INTO v_user_id
  FROM user_sessions
  WHERE token = p_token
  AND expires_at > now();
  
  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Activation RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- Policies de base
CREATE POLICY "Les utilisateurs peuvent voir leur propre profil"
  ON users
  FOR SELECT
  USING (id = current_setting('app.user_id')::uuid);

CREATE POLICY "Les administrateurs peuvent gérer les utilisateurs"
  ON users
  FOR ALL
  USING (
    current_setting('app.user_id')::uuid IN (
      SELECT user_id FROM user_roles WHERE role = 'admin'
    )
  );
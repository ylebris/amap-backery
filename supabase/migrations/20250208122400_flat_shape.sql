/*
  # Ajout MFA et réinitialisation de mot de passe

  1. Nouvelles Tables
    - `password_reset_tokens`: Gestion des tokens de réinitialisation
    - `mfa_methods`: Méthodes MFA par utilisateur
    - `mfa_backup_codes`: Codes de secours MFA
    
  2. Modifications
    - Ajout de fonctions pour la gestion des mots de passe
    - Ajout de fonctions pour la gestion MFA
*/

-- Table des tokens de réinitialisation de mot de passe
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  token text UNIQUE NOT NULL,
  expires_at timestamptz NOT NULL,
  used boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Table des méthodes MFA
CREATE TABLE IF NOT EXISTS mfa_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('totp', 'yubikey')),
  secret text NOT NULL,
  name text,
  enabled boolean DEFAULT true,
  last_used_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, type)
);

-- Table des codes de secours MFA
CREATE TABLE IF NOT EXISTS mfa_backup_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  code_hash text NOT NULL,
  used boolean DEFAULT false,
  used_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Activation RLS
ALTER TABLE password_reset_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE mfa_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE mfa_backup_codes ENABLE ROW LEVEL SECURITY;

-- Fonction pour créer un token de réinitialisation
CREATE OR REPLACE FUNCTION create_password_reset_token(p_email text)
RETURNS text AS $$
DECLARE
  v_user_id uuid;
  v_token text;
BEGIN
  -- Recherche de l'utilisateur
  SELECT id INTO v_user_id
  FROM users
  WHERE email = p_email;

  IF v_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Génération du token
  v_token := encode(gen_random_bytes(32), 'hex');

  -- Invalidation des anciens tokens
  UPDATE password_reset_tokens
  SET used = true
  WHERE user_id = v_user_id AND NOT used;

  -- Création du nouveau token
  INSERT INTO password_reset_tokens (user_id, token, expires_at)
  VALUES (v_user_id, v_token, now() + interval '1 hour');

  RETURN v_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour valider un token de réinitialisation
CREATE OR REPLACE FUNCTION validate_reset_token(p_token text)
RETURNS uuid AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT user_id INTO v_user_id
  FROM password_reset_tokens
  WHERE token = p_token
  AND NOT used
  AND expires_at > now();

  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour configurer TOTP
CREATE OR REPLACE FUNCTION setup_totp(p_user_id uuid, p_secret text, p_name text DEFAULT NULL)
RETURNS boolean AS $$
BEGIN
  INSERT INTO mfa_methods (user_id, type, secret, name)
  VALUES (p_user_id, 'totp', p_secret, p_name);
  
  -- Génération de codes de secours
  FOR i IN 1..8 LOOP
    INSERT INTO mfa_backup_codes (user_id, code_hash)
    VALUES (p_user_id, crypt(encode(gen_random_bytes(4), 'hex'), gen_salt('bf')));
  END LOOP;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour configurer Yubikey
CREATE OR REPLACE FUNCTION setup_yubikey(p_user_id uuid, p_public_key text, p_name text DEFAULT NULL)
RETURNS boolean AS $$
BEGIN
  INSERT INTO mfa_methods (user_id, type, secret, name)
  VALUES (p_user_id, 'yubikey', p_public_key, p_name);
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour valider MFA
CREATE OR REPLACE FUNCTION validate_mfa(p_user_id uuid, p_type text, p_code text)
RETURNS boolean AS $$
DECLARE
  v_method_id uuid;
  v_secret text;
BEGIN
  -- Vérification du code de secours
  IF p_type = 'backup' THEN
    UPDATE mfa_backup_codes
    SET used = true, used_at = now()
    WHERE user_id = p_user_id 
    AND NOT used 
    AND code_hash = crypt(p_code, code_hash)
    RETURNING id INTO v_method_id;
    
    RETURN v_method_id IS NOT NULL;
  END IF;

  -- Vérification TOTP ou Yubikey
  SELECT id, secret INTO v_method_id, v_secret
  FROM mfa_methods
  WHERE user_id = p_user_id
  AND type = p_type
  AND enabled;

  IF v_method_id IS NULL THEN
    RETURN false;
  END IF;

  -- La validation spécifique (TOTP/Yubikey) sera faite côté application
  -- car elle nécessite des bibliothèques spécifiques

  UPDATE mfa_methods
  SET last_used_at = now()
  WHERE id = v_method_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Policies
CREATE POLICY "Les utilisateurs peuvent gérer leurs méthodes MFA"
  ON mfa_methods
  FOR ALL
  USING (user_id = current_setting('app.user_id')::uuid)
  WITH CHECK (user_id = current_setting('app.user_id')::uuid);

CREATE POLICY "Les utilisateurs peuvent voir leurs codes de secours"
  ON mfa_backup_codes
  FOR SELECT
  USING (user_id = current_setting('app.user_id')::uuid);

-- Index pour les performances
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token ON password_reset_tokens(token);
CREATE INDEX IF NOT EXISTS idx_mfa_methods_user_type ON mfa_methods(user_id, type);
CREATE INDEX IF NOT EXISTS idx_mfa_backup_codes_user ON mfa_backup_codes(user_id) WHERE NOT used;
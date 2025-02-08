/*
  # Configuration de l'authentification Supabase
  
  Cette migration :
  1. Supprime les données existantes
  2. Configure l'authentification email/mot de passe
*/

-- Suppression des données existantes
DELETE FROM amap_baker_assignments;
DELETE FROM amap_members;
DELETE FROM amaps;
DELETE FROM user_roles;
DELETE FROM users;
DELETE FROM auth.users;

-- Activation de l'authentification par email
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

-- Policies pour auth.users
CREATE POLICY "Les utilisateurs peuvent voir leur propre profil"
  ON auth.users
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Les super admins peuvent gérer tous les utilisateurs"
  ON auth.users
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND role = 'super_admin'
    )
  );

-- Fonction pour créer un utilisateur
CREATE OR REPLACE FUNCTION create_new_user(
  p_email text,
  p_password text,
  p_first_name text,
  p_last_name text
) RETURNS uuid AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Insérer l'utilisateur dans auth.users
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
    p_email,
    crypt(p_password, gen_salt('bf')),
    jsonb_build_object(
      'first_name', p_first_name,
      'last_name', p_last_name
    ),
    now(),
    now(),
    now(),
    'authenticated',
    'authenticated'
  )
  RETURNING id INTO v_user_id;

  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
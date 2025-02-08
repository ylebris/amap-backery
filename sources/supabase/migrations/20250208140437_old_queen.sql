-- Activation de l'authentification par email
CREATE OR REPLACE FUNCTION auth.email_signup(email text, password text, data jsonb DEFAULT NULL)
RETURNS auth.users AS $$
DECLARE
  user_id uuid;
BEGIN
  -- Création de l'utilisateur
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
    crypt(password, gen_salt('bf')),
    COALESCE(data, '{}'::jsonb),
    now(),
    now(),
    now(),
    'authenticated',
    'authenticated'
  )
  RETURNING id INTO user_id;

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

-- Fonction de connexion par email
CREATE OR REPLACE FUNCTION auth.email_signin(email text, password text)
RETURNS auth.users AS $$
DECLARE
  user_record auth.users;
BEGIN
  SELECT * INTO user_record
  FROM auth.users
  WHERE auth.users.email = email_signin.email
  AND auth.users.encrypted_password = crypt(password, auth.users.encrypted_password);

  IF user_record.id IS NULL THEN
    RAISE EXCEPTION 'Invalid email or password';
  END IF;

  RETURN user_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
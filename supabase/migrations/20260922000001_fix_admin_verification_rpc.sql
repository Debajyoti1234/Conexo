CREATE OR REPLACE FUNCTION public.admin_list_verifications(
  p_limit integer DEFAULT 25,
  p_offset integer DEFAULT 0,
  p_search text DEFAULT '',
  p_verification_status text DEFAULT '',
  p_sort text DEFAULT 'pending_first'
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  email text,
  verification_status text,
  registration_date timestamptz,
  last_updated timestamptz,
  total bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_search text := COALESCE(p_search, '');
  v_status text := COALESCE(p_verification_status, '');
  v_sort text := COALESCE(p_sort, 'pending_first');
  v_search_uuid uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_limit < 1 THEN
    p_limit := 1;
  ELSIF p_limit > 100 THEN
    p_limit := 100;
  END IF;

  IF p_offset < 0 THEN
    p_offset := 0;
  END IF;

  IF v_sort NOT IN ('pending_first', 'newest', 'oldest', 'updated_newest',
                    'updated_oldest', 'name_asc', 'name_desc') THEN
    v_sort := 'pending_first';
  END IF;

  IF v_search ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_search_uuid := v_search::uuid;
  END IF;

  RETURN QUERY
  SELECT
    u.id AS user_id,
    p.display_name,
    u.email::text,
    p.verification_status,
    u.created_at AS registration_date,
    p.updated_at AS last_updated,
    count(*) OVER() AS total
  FROM auth.users u
  JOIN public.profiles p ON p.id = u.id
  WHERE u.deleted_at IS NULL
    AND (
      v_search = ''
      OR p.display_name ILIKE ('%' || v_search || '%')
      OR u.email ILIKE ('%' || v_search || '%')
      OR (v_search_uuid IS NOT NULL AND u.id = v_search_uuid)
    )
    AND (v_status = '' OR p.verification_status = v_status)
  ORDER BY
    CASE WHEN v_sort = 'pending_first' THEN
      CASE p.verification_status
        WHEN 'pending' THEN 1
        WHEN 'notVerified' THEN 2
        WHEN 'verified' THEN 3
      END
    END ASC NULLS LAST,
    CASE WHEN v_sort IN ('pending_first', 'newest') THEN u.created_at END DESC NULLS LAST,
    CASE WHEN v_sort = 'oldest' THEN u.created_at END ASC NULLS LAST,
    CASE WHEN v_sort = 'updated_newest' THEN p.updated_at END DESC NULLS LAST,
    CASE WHEN v_sort = 'updated_oldest' THEN p.updated_at END ASC NULLS LAST,
    CASE WHEN v_sort = 'name_asc' THEN p.display_name END ASC NULLS LAST,
    CASE WHEN v_sort = 'name_desc' THEN p.display_name END DESC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_verifications(integer, integer, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_list_verifications(integer, integer, text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_list_verifications(integer, integer, text, text, text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_verifications(integer, integer, text, text, text) TO authenticated;

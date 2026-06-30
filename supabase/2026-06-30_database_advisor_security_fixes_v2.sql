-- Security Fixes V2: Revoke anonymous execute on SECURITY DEFINER functions for newly added functions
DO $$
DECLARE
    func_record RECORD;
    sql_stmt TEXT;
BEGIN
    FOR func_record IN 
        SELECT 
            ns.nspname AS schema_name,
            p.proname AS function_name,
            oidvectortypes(p.proargtypes) AS arg_types
        FROM pg_proc p
        JOIN pg_namespace ns ON p.pronamespace = ns.oid
        WHERE ns.nspname = 'public' 
          AND p.prosecdef = true
    LOOP
        sql_stmt := format('REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM public, anon CASCADE', 
                           func_record.schema_name, 
                           func_record.function_name, 
                           func_record.arg_types);
        EXECUTE sql_stmt;

        sql_stmt := format('GRANT EXECUTE ON FUNCTION %I.%I(%s) TO authenticated, service_role', 
                           func_record.schema_name, 
                           func_record.function_name, 
                           func_record.arg_types);
        EXECUTE sql_stmt;
    END LOOP;
END;
$$;

-- Security Fixes V2: Set search_path = public on functions without it
DO $$
DECLARE
    func_record RECORD;
    sql_stmt TEXT;
BEGIN
    FOR func_record IN
        SELECT 
            ns.nspname AS schema_name,
            p.proname AS function_name,
            oidvectortypes(p.proargtypes) AS arg_types
        FROM pg_proc p
        JOIN pg_namespace ns ON p.pronamespace = ns.oid
        WHERE ns.nspname = 'public'
          AND (p.proconfig IS NULL OR NOT (p.proconfig @> ARRAY['search_path=public']))
    LOOP
        sql_stmt := format('ALTER FUNCTION %I.%I(%s) SET search_path = public', 
                           func_record.schema_name, 
                           func_record.function_name, 
                           func_record.arg_types);
        EXECUTE sql_stmt;
    END LOOP;
END;
$$;

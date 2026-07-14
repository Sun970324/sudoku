-- Security Advisor flags handle_new_user() (SECURITY DEFINER) as callable via
-- the REST RPC endpoint by anon/authenticated. Postgres already refuses to
-- invoke a RETURNS TRIGGER function outside the trigger mechanism, so this
-- isn't actually exploitable — but revoking direct EXECUTE removes the
-- advisor warning and makes the trigger-only intent explicit.
--
-- New functions grant EXECUTE to the PUBLIC pseudo-role by default, and
-- anon/authenticated inherit through it — so PUBLIC must be revoked too,
-- not just the two named roles.
revoke execute on function public.handle_new_user() from public;
revoke execute on function public.handle_new_user() from anon, authenticated;

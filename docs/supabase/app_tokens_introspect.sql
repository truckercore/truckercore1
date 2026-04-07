-- docs/supabase/app_tokens_introspect.sql
-- Token introspection RPC and minimal revocation registry. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- Optional revocations table referenced by the function (by jti)
create table if not exists public.token_revocations (
  jti text primary key,
  reason text null,
  expires_at timestamptz null,
  created_at timestamptz not null default now()
);

alter table public.token_revocations enable row level security;
-- No client writes; reads not generally required. Leave default RLS (deny all).
revoke insert, update, delete, select on public.token_revocations from authenticated;

-- Token introspection function per spec
create or replace function public.fn_token_introspect(p_token text)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_header jsonb;
  v_payload jsonb;
  v_alg text;
  v_kid text;
  v_iss text;
  v_aud text;
  v_sub text;
  v_org text;
  v_exp int8;
  v_iat int8;
  v_now int8 := extract(epoch from now());
  v_sig_valid boolean := false;
  v_revoked boolean := false;
  v_source text := 'unknown';
begin
  -- naive split (header.payload.signature), base64url decode header/payload only
  begin
    v_header := convert_from(decode(split_part(p_token, '.', 1), 'base64url'), 'utf8')::jsonb;
    v_payload := convert_from(decode(split_part(p_token, '.', 2), 'base64url'), 'utf8')::jsonb;
  exception when others then
    return jsonb_build_object('active', false, 'reason', 'malformed');
  end;

  v_alg := coalesce(v_header->>'alg', '');
  v_kid := v_header->>'kid';
  v_iss := v_payload->>'iss';
  v_aud := v_payload->>'aud';
  v_sub := v_payload->>'sub';
  v_org := v_payload->>'app_org_id';
  v_exp := nullif(v_payload->>'exp','')::bigint;
  v_iat := nullif(v_payload->>'iat','')::bigint;

  -- Simplified signature validation gate (actual cryptographic validation should occur at edge)
  v_sig_valid := (v_alg in ('HS256','RS256')) and (v_iss is not null) and (length(coalesce(split_part(p_token,'.',3),'')) > 0);

  -- Check revocation/jti if present; tolerate missing table
  if v_payload ? 'jti' then
    begin
      select exists(select 1 from public.token_revocations where jti = v_payload->>'jti' and (expires_at is null or expires_at > now()))
      into v_revoked;
    exception when undefined_table then
      v_revoked := false;
    end;
  end if;

  -- Classify source
  if v_payload ? 'app_roles' then v_source := 'app';
  elseif v_payload ? 'role' and (v_payload->>'role') = 'service_role' then v_source := 'service';
  elseif v_payload ? 'provider' and (v_payload->>'provider') in ('azuread','okta','google') then v_source := 'sso';
  end if;

  return jsonb_build_object(
    'active', (v_exp is null or v_exp > v_now) and v_sig_valid and not v_revoked,
    'issuer', v_iss,
    'audience', v_aud,
    'subject', v_sub,
    'org_id', v_org,
    'exp', v_exp,
    'iat', v_iat,
    'revoked', v_revoked,
    'alg', v_alg,
    'kid', v_kid,
    'source', v_source,
    'payload', v_payload
  );
end $$;

revoke all on function public.fn_token_introspect(text) from public;
grant execute on function public.fn_token_introspect(text) to service_role, authenticated;

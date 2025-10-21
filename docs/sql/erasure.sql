create or replace function app.erase_user(p_user uuid)
returns void language plpgsql security definer as $$
begin
  perform set_config('search_path','public,extensions',true);

  -- Anonymize community posts
  update public.forum_posts set author_id = null where author_id = p_user;

  -- Remove PII from profiles
  update public.profiles set name = null, phone = null where user_id = p_user;

  -- Delete tokens/sessions
  delete from public.sessions where user_id = p_user;

  -- Document additional references here as needed.
end $$;

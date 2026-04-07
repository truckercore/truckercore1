begin;

create table if not exists ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  created_at timestamptz default now()
);

create table if not exists ai_messages (
  id bigserial primary key,
  conv_id uuid not null references ai_conversations(id) on delete cascade,
  role text not null check (role in ('user','assistant','system')),
  content text not null,
  created_at timestamptz default now()
);

-- RLS: user can access only own conversations/messages
alter table ai_conversations enable row level security;
alter table ai_messages      enable row level security;

create policy ai_conv_self on ai_conversations
for all using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy ai_msg_self on ai_messages
for all using (exists (select 1 from ai_conversations c where c.id = conv_id and c.user_id = auth.uid()))
with check (exists (select 1 from ai_conversations c where c.id = conv_id and c.user_id = auth.uid()));

create index if not exists idx_ai_msg_conv_time on ai_messages (conv_id, created_at desc);

comment on table ai_conversations is 'Per-user chat threads';
comment on table ai_messages is 'Messages in AI conversations';

commit;

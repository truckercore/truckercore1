begin;

create table if not exists secret_rotations (
  id bigserial primary key,
  key_name text not null,
  rotated_at timestamptz not null default now(),
  rotated_by text not null,
  sha256_pub text,
  evidence_url text
);

commit;

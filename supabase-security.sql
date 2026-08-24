-- ============================================================
--  crew-game · Supabase 보안 설정
--  Supabase 대시보드 → SQL Editor 에 붙여넣고 실행하세요.
--  1번(점검)을 먼저 돌려 현재 상태를 확인한 뒤 2·3번을 적용하는 걸 권장합니다.
-- ============================================================


-- ── 1. 현재 상태 점검 ────────────────────────────────────────
-- rowsecurity 가 false 면 publishable 키만 있는 누구나 데이터를 지울 수 있습니다.
select tablename, rowsecurity
from pg_tables
where schemaname='public' and tablename='tournament_state';

-- 지금 걸려 있는 정책 목록
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname='public' and tablename='tournament_state';

-- 스토리지 버킷 공개 여부
select id, name, public from storage.buckets where id='player-photos';

select policyname, cmd, roles
from pg_policies
where schemaname='storage' and tablename='objects';


-- ── 2. tournament_state : 읽기는 전체 공개, 쓰기는 로그인한 관리자만 ──
alter table public.tournament_state enable row level security;

drop policy if exists "tournament_state public read"  on public.tournament_state;
drop policy if exists "tournament_state admin insert" on public.tournament_state;
drop policy if exists "tournament_state admin update" on public.tournament_state;
drop policy if exists "tournament_state admin delete" on public.tournament_state;

-- 관람자(anon)와 관리자 모두 읽기 가능
create policy "tournament_state public read"
  on public.tournament_state for select
  to anon, authenticated
  using (true);

-- 쓰기는 로그인한 사용자만. saveRemote() 가 upsert 를 쓰므로 insert/update 둘 다 필요합니다.
create policy "tournament_state admin insert"
  on public.tournament_state for insert
  to authenticated
  with check (true);

create policy "tournament_state admin update"
  on public.tournament_state for update
  to authenticated
  using (true) with check (true);

-- 삭제는 아무에게도 허용하지 않습니다(정책이 없으면 거부됩니다).
-- 필요하면 아래 주석을 풀어 authenticated 에만 허용하세요.
-- create policy "tournament_state admin delete"
--   on public.tournament_state for delete to authenticated using (true);


-- ── 3. player-photos 버킷 : 읽기 공개, 업로드/수정/삭제는 관리자만 ──
update storage.buckets set public = true where id = 'player-photos';

drop policy if exists "player-photos public read"   on storage.objects;
drop policy if exists "player-photos admin insert"  on storage.objects;
drop policy if exists "player-photos admin update"  on storage.objects;
drop policy if exists "player-photos admin delete"  on storage.objects;

create policy "player-photos public read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'player-photos');

-- upsert:true 로 올리므로 insert 와 update 가 모두 필요합니다.
create policy "player-photos admin insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'player-photos');

create policy "player-photos admin update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'player-photos')
  with check (bucket_id = 'player-photos');

create policy "player-photos admin delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'player-photos');


-- ── 4. 관리자 계정 확인 ──────────────────────────────────────
-- 여기 나오는 사람은 전부 대회 데이터를 고칠 수 있습니다.
-- 모르는 계정이 있으면 Authentication → Users 에서 삭제하세요.
-- 신규 가입은 Authentication → Providers → Email 에서 "Allow new users to sign up" 을 꺼두는 편이 안전합니다.
select id, email, created_at, last_sign_in_at
from auth.users
order by created_at;


-- ── 5. 적용 후 재점검 ────────────────────────────────────────
-- 여기서 anon 에게 select 만 보이면 정상입니다.
select policyname, cmd, roles
from pg_policies
where schemaname='public' and tablename='tournament_state'
order by cmd;

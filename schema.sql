-- Legendshub.uz: Supabase > SQL Editor ichiga to'liq joylab "Run" bosing

create table profiles(
  id uuid primary key references auth.users on delete cascade,
  nick text not null default 'Haydovchi',
  bio text default '',
  created_at timestamptz default now());
create table posts(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  car text not null, body text default '', image_url text, media_type text default 'image',
  created_at timestamptz default now());
create table likes(
  post_id uuid references posts(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  primary key(post_id,user_id));
create table comments(
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  body text not null, created_at timestamptz default now());
create table views(
  post_id uuid references posts(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  primary key(post_id,user_id));
create table scores(
  user_id uuid references profiles(id) on delete cascade,
  week int not null, pts int not null,
  primary key(user_id,week));

-- Yangi foydalanuvchi uchun profil avtomatik yaratiladi
create function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into profiles(id,nick) values(new.id, coalesce(nullif(new.raw_user_meta_data->>'nick',''),'Haydovchi'));
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

-- Premium shartlari: 3 post, 5 izoh, 5 like
create function is_premium(u uuid) returns boolean language sql security definer set search_path=public as $$
  select (select count(*) from posts where user_id=u)>=3
     and (select count(*) from comments where user_id=u)>=5
     and (select count(*) from likes where user_id=u)>=5 $$;

alter table profiles enable row level security;
alter table posts enable row level security;
alter table likes enable row level security;
alter table comments enable row level security;
alter table views enable row level security;
alter table scores enable row level security;

create policy "o'qish" on profiles for select using (true);
create policy "o'qish" on posts for select using (true);
create policy "o'qish" on likes for select using (true);
create policy "o'qish" on comments for select using (true);
create policy "o'qish" on views for select using (true);
create policy "o'qish" on scores for select using (true);

create policy "profilni tahrirlash" on profiles for update using (auth.uid()=id);
create policy "post qo'shish" on posts for insert with check (auth.uid()=user_id);
create policy "post o'chirish" on posts for delete using (auth.uid()=user_id);
create policy "like qo'shish" on likes for insert with check (auth.uid()=user_id);
create policy "like olib tashlash" on likes for delete using (auth.uid()=user_id);
create policy "izoh qo'shish" on comments for insert with check (auth.uid()=user_id);
create policy "izoh o'chirish" on comments for delete using (auth.uid()=user_id);
create policy "ko'rish qo'shish" on views for insert with check (auth.uid()=user_id);
create policy "ball yozish (faqat premium)" on scores for insert with check (auth.uid()=user_id and is_premium(auth.uid()));

-- Rasm saqlash
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
  values('cars','cars',true,52428800,array['image/*','video/*']) on conflict do nothing;
create policy "rasmlarni ko'rish" on storage.objects for select using (bucket_id='cars');
create policy "rasm yuklash" on storage.objects for insert to authenticated
  with check (bucket_id='cars' and (storage.foldername(name))[1]=auth.uid()::text);

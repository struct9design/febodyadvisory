-- Private buckets. Paths start with the client id: checkins/<client_id>/…, documents/<client_id>/…
-- Files are served through short-lived signed URLs.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('checkins', 'checkins', false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'image/heic']),
  ('videos', 'videos', false, 524288000, array['video/mp4', 'video/quicktime', 'video/webm', 'image/jpeg', 'image/webp']),
  ('documents', 'documents', false, 10485760, array['application/pdf', 'image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create function private.folder_client(object_name text) returns uuid
language sql immutable set search_path = '' as $$
  select case
    when (storage.foldername(object_name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then (storage.foldername(object_name))[1]::uuid
  end
$$;

revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;

-- checkins: progress photos
create policy "checkins: client own" on storage.objects for all to authenticated
  using (bucket_id = 'checkins' and private.folder_client(name) = private.my_client_id())
  with check (bucket_id = 'checkins' and private.folder_client(name) = private.my_client_id());
create policy "checkins: staff read" on storage.objects for select to authenticated
  using (bucket_id = 'checkins' and private.staff_reads_health(private.folder_client(name)));

-- videos: exercise library
create policy "videos: read" on storage.objects for select to authenticated
  using (bucket_id = 'videos');
create policy "videos: library write" on storage.objects for insert to authenticated
  with check (bucket_id = 'videos' and private.has_perm('biblioteca') and private.auth_role() <> 'billing');
create policy "videos: library update" on storage.objects for update to authenticated
  using (bucket_id = 'videos' and private.has_perm('biblioteca') and private.auth_role() <> 'billing');
create policy "videos: library delete" on storage.objects for delete to authenticated
  using (bucket_id = 'videos' and private.has_perm('biblioteca') and private.auth_role() <> 'billing');

-- documents: invoices, payment proofs, signed contracts
create policy "documents: client read own" on storage.objects for select to authenticated
  using (bucket_id = 'documents' and private.folder_client(name) = private.my_client_id());
create policy "documents: client upload proof" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'documents'
    and private.folder_client(name) = private.my_client_id()
    and (storage.foldername(name))[2] = 'justificantes'
  );
create policy "documents: billing" on storage.objects for all to authenticated
  using (
    bucket_id = 'documents'
    and (private.has_perm('pagos') or private.has_perm('contratos'))
    and private.can_admin_client(private.folder_client(name))
  )
  with check (
    bucket_id = 'documents'
    and (private.has_perm('pagos') or private.has_perm('contratos'))
    and private.can_admin_client(private.folder_client(name))
  );

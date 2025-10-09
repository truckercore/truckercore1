-- 903_storage_buckets.sql
-- Create a private 'docs' bucket and a read policy scoped by bucket

INSERT INTO storage.buckets (id, name, public)
VALUES ('docs', 'docs', false)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='storage' AND tablename='objects' AND policyname='doc_read_org'
  ) THEN
    CREATE POLICY doc_read_org
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
      bucket_id = 'docs'
    );
  END IF;
END $$;

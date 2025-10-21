import { createClient } from '@supabase/supabase-js'

export type ApiError = { status: number; code?: string; message: string; requestId?: string }
export type ServiceResult<T> = { data: T | null; error: ApiError | null; requestId: string }

function normalizeError(err: any, status?: number, requestId?: string): ApiError {
  return { status: status ?? (typeof err?.status === 'number' ? err.status : 500), code: err?.code, message: err?.message ?? 'Unexpected error', requestId }
}

function getClientOrError(requestId: string): { client?: ReturnType<typeof createClient>; error?: ApiError } {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) return { error: { status: 500, code: 'env_missing', message: 'Supabase env not set', requestId } }
  return { client: createClient(url, key, { global: { headers: { 'x-request-id': requestId } } }) }
}

export async function listSafetyIncidents(): Promise<ServiceResult<any[]>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }
    const { data, error: qErr, status } = await (client as any)!
      .from('safety_incidents')
      .select('*')
      .order('occurred_at', { ascending: false })
    if (qErr) return { data: null, error: normalizeError(qErr, status, requestId), requestId }
    return { data: data ?? [], error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export async function createCoachingTask(input: { driver_id: string; note: string; incident_id?: string | null; assignee_id?: string | null; due_date?: string | null }): Promise<ServiceResult<any>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }
    const payload: any = { driver_id: input.driver_id, note: input.note }
    if (input.incident_id) payload.incident_id = input.incident_id
    if (input.assignee_id) payload.assignee_id = input.assignee_id
    if (input.due_date) payload.due_date = input.due_date
    const { data, error: qErr, status } = await (client as any)!
      .from('safety_coaching')
      .insert(payload)
      .select('*')
      .single()
    if (qErr || !data) return { data: null, error: normalizeError(qErr, status, requestId), requestId }
    return { data, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export async function listSafetyScores(): Promise<ServiceResult<any[]>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }
    const { data, error: qErr, status } = await (client as any)!
      .from('safety_scores')
      .select('*')
      .order('updated_at', { ascending: false })
    if (qErr) return { data: null, error: normalizeError(qErr, status, requestId), requestId }
    return { data: data ?? [], error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export async function addAcknowledgementNote(incident_id: string): Promise<ServiceResult<any>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }
    const note = `Driver acknowledged at ${new Date().toISOString()}`
    const { data, error: qErr, status } = await (client as any)!
      .from('safety_coaching')
      .insert({ incident_id, note })
      .select('*')
      .single()
    if (qErr || !data) return { data: null, error: normalizeError(qErr, status, requestId), requestId }
    return { data, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export async function resolveIncident(incident_id: string): Promise<ServiceResult<any>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }
    const { data, error: qErr, status } = await (client as any)!
      .from('safety_incidents')
      .update({ resolved: true, resolved_at: new Date().toISOString() })
      .eq('id', incident_id)
      .select('*')
      .single()
    if (qErr || !data) return { data: null, error: normalizeError(qErr, status, requestId), requestId }
    return { data, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

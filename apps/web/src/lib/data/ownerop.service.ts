import { createClient } from '@supabase/supabase-js'
import type { OwnerOpExpense } from '@/types/db'

export type ApiError = { status: number; code?: string; message: string; requestId?: string }
export type ServiceResult<T> = { data: T | null; error: ApiError | null; requestId: string }

function normalizeError(err: any, status?: number, requestId?: string): ApiError {
  return { status: status ?? (typeof err?.status === 'number' ? err.status : 500), code: err?.code, message: err?.message ?? 'Unexpected error', requestId }
}

function getClientOrError(requestId: string): { client?: ReturnType<typeof createClient>; error?: ApiError } {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) {
    return { error: { status: 500, code: 'env_missing', message: 'Supabase env not set', requestId } }
  }
  return { client: createClient(url, key, { global: { headers: { 'x-request-id': requestId } } }) }
}

export type ListExpensesInput = { driverId: string; from?: string; to?: string }
export async function listExpenses(input: ListExpensesInput): Promise<ServiceResult<OwnerOpExpense[]>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }

    let q = (client as any)!
      .from('ownerop_expenses')
      .select('id,driver_id,load_id,category,amount_usd,miles,occurred_at,note')
      .eq('driver_id', input.driverId)
      .order('occurred_at', { ascending: false })

    if (input.from) q = q.gte('occurred_at', input.from)
    if (input.to) q = q.lte('occurred_at', input.to)

    const { data, error: qErr, status } = await q
    if (qErr) return { data: null, error: normalizeError(qErr, status, requestId), requestId }
    return { data: (data ?? []) as OwnerOpExpense[], error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export type CreateExpenseInput = Omit<OwnerOpExpense, 'id'>
export async function createExpense(input: CreateExpenseInput): Promise<ServiceResult<OwnerOpExpense>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }

    const { data, error: qErr, status } = await (client as any)!
      .from('ownerop_expenses')
      .insert(input as any)
      .select('id,driver_id,load_id,category,amount_usd,miles,occurred_at,note')
      .single()

    if (qErr || !data) return { data: null, error: normalizeError(qErr, status, requestId), requestId }
    return { data: data as OwnerOpExpense, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export async function updateExpense(id: string, patch: Partial<CreateExpenseInput>): Promise<ServiceResult<OwnerOpExpense>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }

    const { data, error: qErr, status } = await (client as any)!
      .from('ownerop_expenses')
      .update(patch as any)
      .eq('id', id)
      .select('id,driver_id,load_id,category,amount_usd,miles,occurred_at,note')
      .single()

    if (qErr || !data) return { data: null, error: normalizeError(qErr, status, requestId), requestId }
    return { data: data as OwnerOpExpense, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export async function deleteExpense(id: string): Promise<ServiceResult<{ id: string }>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }

    const { error: qErr, status } = await (client as any)!
      .from('ownerop_expenses')
      .delete()
      .eq('id', id)

    if (qErr) return { data: null, error: normalizeError(qErr, status, requestId), requestId }
    return { data: { id }, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export type ExpensesSummary = { total: number; miles: number; costPerMile: number }
export function summarizeExpenses(rows: OwnerOpExpense[]): ExpensesSummary {
  const total = rows.reduce((acc, r) => acc + (r.amount_usd ?? 0), 0)
  const miles = rows.reduce((acc, r) => acc + (r.miles ?? 0), 0)
  const costPerMile = miles > 0 ? total / miles : 0
  return { total, miles, costPerMile }
}

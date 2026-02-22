/* eslint-disable no-await-in-loop, no-continue, max-statements */
// biome-ignore-all lint/performance/noAwaitInLoops: x
// biome-ignore-all lint/nursery/noContinue: x
import type { RegisteredQuery } from 'convex/server'
import type { ZodRawShape } from 'zod/v4'

import { zid } from 'convex-helpers/server/zod4'
import { ConvexError } from 'convex/values'
import { nullable, number, object, string } from 'zod/v4'

import type {
  ComparisonOp,
  DbLike,
  ErrorCode,
  FID,
  MutationCtxLike,
  PaginationOptsShape,
  Qb,
  QueryCtxLike,
  RateLimitConfig,
  StorageLike,
  WithUrls
} from './types'

import { cvFileKindOf } from '../zod'
import { flt, idx, typed } from './bridge'
import { ERROR_MESSAGES } from './types'

const TOKEN_BYTES = 24,
  TOKEN_RADIX = 36,
  TOKEN_LENGTH = 32,
  SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000, // eslint-disable-line @typescript-eslint/no-magic-numbers
  generateToken = () => {
    const bytes = new Uint8Array(TOKEN_BYTES)
    crypto.getRandomValues(bytes)
    let token = ''
    for (const b of bytes) token += b.toString(TOKEN_RADIX).padStart(2, '0').slice(0, 2)
    return token.slice(0, TOKEN_LENGTH)
  },
  RUNTIME_FILTER_WARN_THRESHOLD = 1000,
  log = (level: 'debug' | 'error' | 'info' | 'warn', msg: string, data?: Record<string, unknown>) => {
    // eslint-disable-next-line no-console
    console[level](JSON.stringify({ level, msg, ts: Date.now(), ...data }))
  },
  // eslint-disable-next-line @typescript-eslint/max-params
  warnLargeFilterSet = (count: number, table: string, context: string, strict?: boolean) => {
    if (count > RUNTIME_FILTER_WARN_THRESHOLD) {
      const msg = `Runtime filtering ${count} docs in "${table}" (${context}) exceeds ${RUNTIME_FILTER_WARN_THRESHOLD} threshold. Add a Convex index for better performance.`
      if (strict) throw new Error(msg)
      log('warn', 'query:large_filter_set', {
        context,
        count,
        table,
        threshold: RUNTIME_FILTER_WARN_THRESHOLD
      })
    }
  },
  isRecord = (v: unknown): v is Record<string, unknown> => Boolean(v) && typeof v === 'object',
  isComparisonOp = (val: unknown): val is ComparisonOp<unknown> =>
    typeof val === 'object' &&
    val !== null &&
    ('$gt' in val || '$gte' in val || '$lt' in val || '$lte' in val || '$between' in val),
  pgOpts = object({
    cursor: nullable(string()),
    endCursor: nullable(string()).optional(),
    id: number().optional(),
    maximumBytesRead: number().optional(),
    maximumRowsRead: number().optional(),
    numItems: number()
  } satisfies PaginationOptsShape),
  detectFiles = <S extends ZodRawShape>(s: S) => (Object.keys(s) as (keyof S & string)[]).filter(k => cvFileKindOf(s[k])),
  err = (code: ErrorCode, opts?: string | { message: string }): never => {
    if (!opts) throw new ConvexError({ code })
    if (typeof opts === 'string') throw new ConvexError({ code, debug: opts })
    throw new ConvexError({ code, ...opts })
  },
  noFetcher = (): never => err('NO_FETCHER'),
  time = () => ({ updatedAt: Date.now() }),
  getUser = async ({
    ctx,
    db,
    getAuthUserId
  }: {
    ctx: MutationCtxLike | QueryCtxLike
    db: DbLike
    getAuthUserId: (c: never) => Promise<null | string>
  }): Promise<Record<string, unknown> & { _id: string }> => {
    const uid = await getAuthUserId(typed(ctx))
    if (!uid) return err('NOT_AUTHENTICATED')
    const u = await db.get(uid)
    return (u ?? err('USER_NOT_FOUND')) as Record<string, unknown> & { _id: string }
  },
  ownGet =
    (db: DbLike, userId: string) =>
    async (id: string): Promise<Record<string, unknown>> => {
      const d = await db.get(id)
      return d && (d as { userId?: string }).userId === userId ? d : err('NOT_FOUND')
    },
  readCtx = <D = DbLike, S = StorageLike>({ db, storage, viewerId }: { db: D; storage: S; viewerId: null | string }) => ({
    db,
    storage,
    viewerId,
    withAuthor: async <T extends { userId: string }>(docs: T[]) => {
      const ids = [...new Set(docs.map(d => d.userId))],
        users = await Promise.all(ids.map(async id => (db as DbLike).get(id))),
        map = new Map(ids.map((id, i) => [id, users[i]] as const))
      return docs.map(d => ({ ...d, author: map.get(d.userId) ?? null, own: viewerId ? viewerId === d.userId : null }))
    }
  }),
  toId = (x: unknown): FID | null => (typeof x === 'string' ? (x as FID) : null),
  cleanFiles = async (opts: {
    doc: Record<string, unknown>
    fileFields: string[]
    next?: Record<string, unknown>
    storage: StorageLike
  }) => {
    const { doc, fileFields, next, storage } = opts
    if (!fileFields.length) return
    const del = new Set<FID>()
    for (const f of fileFields) {
      const prev = doc[f]
      if (prev === null) continue
      const pArr = Array.isArray(prev) ? prev : [prev]
      if (!next) {
        for (const p of pArr) {
          const id = toId(p)
          if (id) del.add(id)
        }
        continue
      }
      if (!Object.hasOwn(next, f)) continue
      const nv = next[f],
        keep = new Set(Array.isArray(nv) ? nv : nv ? [nv] : [])
      for (const p of pArr)
        if (!keep.has(p as FID)) {
          const id = toId(p)
          if (id) del.add(id)
        }
    }
    if (del.size) {
      const results = await Promise.allSettled([...del].map(async id => storage.delete(id)))
      for (const r of results)
        if (r.status === 'rejected') log('warn', 'file:cleanup_failed', { reason: String(r.reason) })
    }
  },
  addUrls = async <D extends Record<string, unknown>>({
    doc,
    fileFields,
    storage
  }: {
    doc: D
    fileFields: string[]
    storage: StorageLike
  }): Promise<WithUrls<D>> => {
    if (!fileFields.length) return doc as WithUrls<D>
    const o = { ...doc } as Record<string, unknown>,
      getUrl = async (x: unknown) => {
        const id = toId(x)
        return id ? storage.getUrl(id) : null
      }
    for (const f of fileFields) {
      const fv = doc[f]
      if (fv !== null)
        o[Array.isArray(fv) ? `${f}Urls` : `${f}Url`] = Array.isArray(fv)
          ? await Promise.all(fv.map(getUrl))
          : await getUrl(fv)
    }
    return o as WithUrls<D>
  },
  matchField = (docVal: unknown, filterVal: unknown): boolean => {
    if (isComparisonOp(filterVal)) {
      const dv = docVal as number
      if (filterVal.$gt !== undefined && !(dv > (filterVal.$gt as number))) return false
      if (filterVal.$gte !== undefined && !(dv >= (filterVal.$gte as number))) return false
      if (filterVal.$lt !== undefined && !(dv < (filterVal.$lt as number))) return false
      if (filterVal.$lte !== undefined && !(dv <= (filterVal.$lte as number))) return false
      if (filterVal.$between !== undefined) {
        const [min, max] = filterVal.$between as [number, number]
        if (!(dv >= min && dv <= max)) return false
      }
      return true
    }
    return Object.is(docVal, filterVal)
  },
  groupList = <WG extends Record<string, unknown> & { own?: boolean }>(w?: WG & { or?: WG[] }): WG[] =>
    w
      ? [{ ...w, or: undefined } as WG, ...(w.or ?? [])].filter(
          g => g.own ?? Object.keys(g).some(k => k !== 'own' && g[k] !== undefined)
        )
      : [],
  matchW = <WG extends Record<string, unknown> & { own?: boolean }>(
    doc: Record<string, unknown>,
    w: undefined | (WG & { or?: WG[] }),
    vid?: null | string
  ) => {
    const gs = groupList(w)
    if (!gs.length) return true
    for (const g of gs) {
      const ok = Object.entries(g).every(
        ([k, vl]: [string, unknown]) => k === 'own' || vl === undefined || matchField(doc[k], vl)
      )
      if (ok && (!g.own || vid === (doc as { userId?: string }).userId)) return true
    }
    return false
  },
  pickFields = (data: Record<string, unknown>, keys: string[]): Record<string, unknown> => {
    const result: Record<string, unknown> = {}
    for (const k of keys) if (k in data) result[k] = data[k]
    return result
  },
  errValidation = (
    code: ErrorCode,
    zodError: { flatten: () => { fieldErrors: Record<string, string[] | undefined> } }
  ): never => {
    const { fieldErrors } = zodError.flatten(),
      fields = Object.keys(fieldErrors)
    throw new ConvexError({ code, fields, message: fields.length ? `Invalid: ${fields.join(', ')}` : 'Validation failed' })
  },
  dbInsert = async (db: DbLike, table: string, data: Record<string, unknown>) => db.insert(table, data),
  dbPatch = async (db: DbLike, id: string, data: Record<string, unknown>) => db.patch(id, data),
  dbDelete = async (db: DbLike, id: string) => db.delete(id),
  checkRateLimit = async (db: DbLike, opts: { config: RateLimitConfig; key: string; table: string }) => {
    const { config, key, table } = opts,
      now = Date.now(),
      existing = await db
        .query('rateLimit')
        .withIndex(
          'by_table_key',
          idx(q => q.eq('table', table).eq('key', key))
        )
        .first()
    if (!existing) {
      await db.insert('rateLimit', { count: 1, key, table, windowStart: now })
      return
    }
    const windowExpired = now - (existing.windowStart as number) >= config.window
    if (windowExpired) {
      await db.patch(existing._id as string, { count: 1, windowStart: now })
      return
    }
    if ((existing.count as number) >= config.max) return err('RATE_LIMITED', `${table}:create`)
    await db.patch(existing._id as string, { count: (existing.count as number) + 1 })
  }

interface ConvexErrorData {
  code: ErrorCode
  debug?: string
  fields?: string[]
  message?: string
}

type ErrorHandler = Partial<Record<ErrorCode, (data: ConvexErrorData) => void>> & {
  default?: (error: unknown) => void
}

const extractErrorData = (e: unknown): ConvexErrorData | undefined => {
    if (!(e instanceof ConvexError)) return
    const { data } = e as { data?: unknown }
    if (!isRecord(data)) return
    const { code } = data
    if (typeof code !== 'string' || !(code in ERROR_MESSAGES)) return
    return {
      code: code as ErrorCode,
      debug: typeof data.debug === 'string' ? data.debug : undefined,
      fields: Array.isArray(data.fields) ? (data.fields as string[]) : undefined,
      message: typeof data.message === 'string' ? data.message : undefined
    }
  },
  getErrorCode = (e: unknown): ErrorCode | undefined => extractErrorData(e)?.code,
  getErrorMessage = (e: unknown): string => {
    const d = extractErrorData(e)
    if (d) return d.message ?? ERROR_MESSAGES[d.code]
    if (e instanceof Error) return e.message
    return 'Unknown error'
  },
  handleConvexError = (e: unknown, handlers: ErrorHandler): void => {
    const d = extractErrorData(e)
    if (d) {
      const handler = handlers[d.code]
      if (handler) {
        handler(d)
        return
      }
    }
    handlers.default?.(e)
  },
  makeUnique = ({
    field,
    index,
    pq,
    table
  }: {
    field: string
    index?: string
    pq: Qb
    table: string
  }): RegisteredQuery<'public', { exclude?: string; value: string }, boolean> =>
    typed(
      pq({
        args: { exclude: zid(table).optional(), value: string() },
        handler: typed(async (c: QueryCtxLike, { exclude, value }: { exclude?: string; value: string }) => {
          const q = c.db.query(table),
            existing = index
              ? await q
                  .withIndex(
                    index,
                    idx(i => i.eq(field, value))
                  )
                  .first()
              : await q.filter(flt(f => f.eq(f.field(field), value))).first()
          return !(existing as null | Record<string, unknown>) || (existing as Record<string, unknown>)._id === exclude
        })
      })
    )

export type { ConvexErrorData, ErrorHandler }
export {
  addUrls,
  checkRateLimit,
  cleanFiles,
  dbDelete,
  dbInsert,
  dbPatch,
  detectFiles,
  err,
  errValidation,
  extractErrorData,
  generateToken,
  getErrorCode,
  getErrorMessage,
  getUser,
  groupList,
  handleConvexError,
  isComparisonOp,
  isRecord,
  log,
  makeUnique,
  matchW,
  noFetcher,
  ownGet,
  pgOpts,
  pickFields,
  readCtx,
  RUNTIME_FILTER_WARN_THRESHOLD,
  SEVEN_DAYS_MS,
  time,
  warnLargeFilterSet
}

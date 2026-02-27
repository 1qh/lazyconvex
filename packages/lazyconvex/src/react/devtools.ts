'use client'
import { useEffect, useMemo, useState } from 'react'

import type { ConvexErrorData } from '../server/helpers'

import { extractErrorData, getErrorDetail, getErrorMessage } from '../server/helpers'

interface DevCacheEntry {
  hitCount: number
  id: number
  key: string
  lastAccess: number
  missCount: number
  stale: boolean
  table: string
}

interface DevError {
  data?: ConvexErrorData
  detail: string
  id: number
  message: string
  timestamp: number
}

interface DevMutation {
  args: string
  durationMs: number
  endedAt: number
  id: number
  name: string
  startedAt: number
  status: 'error' | 'pending' | 'success'
}

interface DevSubscription {
  args: string
  firstResultAt: number
  id: number
  lastUpdate: number
  latencyMs: number
  query: string
  startedAt: number
  status: 'error' | 'loaded' | 'loading'
  updateCount: number
}

const MAX_ERRORS = 50,
  MAX_MUTATIONS = 100,
  SLOW_THRESHOLD_MS = 5000,
  STALE_THRESHOLD_MS = 30_000,
  errorStore: DevError[] = [],
  mutationStore: DevMutation[] = [],
  cacheStore = new Map<string, DevCacheEntry>(),
  subStore = new Map<number, DevSubscription>()

let nextId = 1,
  listeners: (() => void)[] = []

const notify = () => {
    for (const fn of listeners) fn()
  },
  pushError = (e: unknown) => {
    const data = extractErrorData(e),
      entry: DevError = {
        data,
        detail: getErrorDetail(e),
        id: nextId,
        message: getErrorMessage(e),
        timestamp: Date.now()
      }
    nextId += 1
    errorStore.unshift(entry)
    if (errorStore.length > MAX_ERRORS) errorStore.length = MAX_ERRORS
    notify()
  },
  clearErrors = () => {
    errorStore.length = 0
    notify()
  },
  trackSubscription = (query: string, args?: Record<string, unknown>): number => {
    const id = nextId
    nextId += 1
    subStore.set(id, {
      args: args ? JSON.stringify(args) : '{}',
      firstResultAt: 0,
      id,
      lastUpdate: 0,
      latencyMs: 0,
      query,
      startedAt: Date.now(),
      status: 'loading',
      updateCount: 0
    })
    notify()
    return id
  },
  updateSubscription = (id: number, status: 'error' | 'loaded' | 'loading') => {
    const sub = subStore.get(id)
    if (!sub) return
    const now = Date.now()
    if (sub.firstResultAt === 0 && status === 'loaded') {
      sub.firstResultAt = now
      sub.latencyMs = now - sub.startedAt
    }
    sub.status = status
    sub.lastUpdate = now
    sub.updateCount += 1
    notify()
  },
  untrackSubscription = (id: number) => {
    subStore.delete(id)
    notify()
  },
  trackMutation = (name: string, args?: Record<string, unknown>): number => {
    const id = nextId
    nextId += 1
    mutationStore.unshift({
      args: args ? JSON.stringify(args) : '{}',
      durationMs: 0,
      endedAt: 0,
      id,
      name,
      startedAt: Date.now(),
      status: 'pending'
    })
    if (mutationStore.length > MAX_MUTATIONS) mutationStore.length = MAX_MUTATIONS
    notify()
    return id
  },
  completeMutation = (id: number, status: 'error' | 'success') => {
    const entry = mutationStore.find(m => m.id === id)
    if (!entry) return
    entry.status = status
    entry.endedAt = Date.now()
    entry.durationMs = entry.endedAt - entry.startedAt
    notify()
  },
  getOrCreateCacheEntry = (table: string, key: string) => {
    const cacheKey = `${table}:${key}`
    let entry = cacheStore.get(cacheKey)
    if (!entry) {
      const id = nextId
      nextId += 1
      entry = { hitCount: 0, id, key, lastAccess: 0, missCount: 0, stale: false, table }
      cacheStore.set(cacheKey, entry)
    }
    return entry
  },
  trackCacheAccess = (opts: { hit: boolean; key: string; stale?: boolean; table: string }) => {
    const entry = getOrCreateCacheEntry(opts.table, opts.key)
    entry.lastAccess = Date.now()
    if (opts.hit) entry.hitCount += 1
    else entry.missCount += 1
    if (opts.stale !== undefined) entry.stale = opts.stale
    notify()
  },
  clearMutations = () => {
    mutationStore.length = 0
    notify()
  },
  useDevErrors = () => {
    const [, setTick] = useState(0)
    useEffect(() => {
      const fn = () => setTick(t => t + 1)
      listeners.push(fn)
      return () => {
        listeners = listeners.filter(l => l !== fn)
      }
    }, [])
    return useMemo(
      () => ({
        cache: [...cacheStore.values()],
        clear: clearErrors,
        clearMutations,
        errors: [...errorStore],
        mutations: [...mutationStore],
        push: pushError,
        subscriptions: [...subStore.values()]
      }),
      // eslint-disable-next-line react-hooks/exhaustive-deps
      [errorStore.length, mutationStore.length, subStore.size, cacheStore.size]
    )
  }

export type { DevCacheEntry, DevError, DevMutation, DevSubscription }
export {
  clearErrors,
  clearMutations,
  completeMutation,
  pushError,
  SLOW_THRESHOLD_MS,
  STALE_THRESHOLD_MS,
  trackCacheAccess,
  trackMutation,
  trackSubscription,
  untrackSubscription,
  updateSubscription,
  useDevErrors
}

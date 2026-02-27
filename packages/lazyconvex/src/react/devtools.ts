'use client'
import { useEffect, useMemo, useState } from 'react'

import type { ConvexErrorData } from '../server/helpers'

import { extractErrorData, getErrorDetail, getErrorMessage } from '../server/helpers'

interface DevError {
  data?: ConvexErrorData
  detail: string
  id: number
  message: string
  timestamp: number
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
  SLOW_THRESHOLD_MS = 5000,
  STALE_THRESHOLD_MS = 30_000,
  errorStore: DevError[] = [],
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
        clear: clearErrors,
        errors: [...errorStore],
        push: pushError,
        subscriptions: [...subStore.values()]
      }),
      // eslint-disable-next-line react-hooks/exhaustive-deps
      [errorStore.length, subStore.size]
    )
  }

export type { DevError, DevSubscription }
export {
  clearErrors,
  pushError,
  SLOW_THRESHOLD_MS,
  STALE_THRESHOLD_MS,
  trackSubscription,
  untrackSubscription,
  updateSubscription,
  useDevErrors
}

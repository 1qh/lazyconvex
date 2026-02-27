'use client'

import type { FunctionReference, OptionalRestArgs } from 'convex/server'

import { useAction, useQuery } from 'convex/react'
import { useCallback, useEffect, useRef, useState } from 'react'

type ActionRef = FunctionReference<'action'>
type QueryRef = FunctionReference<'query'>

interface UseCacheEntryOptions<Q extends QueryRef, A extends ActionRef> {
  args: OptionalRestArgs<Q>[0]
  get: Q
  load: A
}

interface UseCacheEntryResult<T> {
  data: null | T
  isLoading: boolean
  isStale: boolean
  refresh: () => void
}

const fireLoad = async (
  load: (a: Record<string, unknown>) => Promise<unknown>,
  args: Record<string, unknown>,
  loadingRef: React.MutableRefObject<boolean>,
  setIsLoading: (v: boolean) => void
) => {
  try {
    await load(args)
  } catch {
    /* oxlint-disable-next-line no-empty */
  } finally {
    loadingRef.current = false
    setIsLoading(false)
  }
},

 useCacheEntry = <Q extends QueryRef, A extends ActionRef>({
  args,
  get: getRef,
  load: loadRef
}: UseCacheEntryOptions<Q, A>): UseCacheEntryResult<Record<string, unknown>> => {
  const cached = useQuery(getRef, args ?? {}),
    load = useAction(loadRef),
    [isLoading, setIsLoading] = useState(false),
    loadingRef = useRef(false),
    argsRef = useRef(args)

  argsRef.current = args

  useEffect(() => {
    if (loadingRef.current) return
    const isStale = cached !== undefined && (cached === null || (cached as Record<string, unknown>).stale === true)
    if (!isStale) return
    loadingRef.current = true
    setIsLoading(true)
    fireLoad(load as (a: Record<string, unknown>) => Promise<unknown>, argsRef.current ?? {}, loadingRef, setIsLoading)
  }, [cached, load])

  const refresh = useCallback(() => {
    if (loadingRef.current) return
    loadingRef.current = true
    setIsLoading(true)
    fireLoad(load as (a: Record<string, unknown>) => Promise<unknown>, argsRef.current ?? {}, loadingRef, setIsLoading)
  }, [load]),

   data = cached === undefined ? null : (cached as null | Record<string, unknown>),
    isStale = data !== null && (data).stale === true

  return { data, isLoading: isLoading || cached === undefined, isStale, refresh }
}

export type { UseCacheEntryOptions, UseCacheEntryResult }
export { useCacheEntry }

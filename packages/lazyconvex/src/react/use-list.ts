'use client'

import type { PaginatedQueryArgs, PaginatedQueryReference } from 'convex/react'
import type { FunctionReturnType } from 'convex/server'

import { usePaginatedQuery } from 'convex/react'
import { useEffect, useRef } from 'react'

import { trackSubscription, untrackSubscription, updateSubscription } from './devtools'

type ListItems<F extends PaginatedQueryReference> = FunctionReturnType<F>['page']

type ListRest<F extends PaginatedQueryReference> =
  PaginatedQueryArgs<F> extends Record<string, never>
    ? [args?: PaginatedQueryArgs<F>, options?: UseListOptions]
    : [args: PaginatedQueryArgs<F>, options?: UseListOptions]
interface UseListOptions {
  pageSize?: number
}
const isDev = typeof process !== 'undefined' && process.env.NODE_ENV !== 'production',
  DEFAULT_PAGE_SIZE = 50,
  useList = <F extends PaginatedQueryReference>(query: F, ...rest: ListRest<F>) => {
    const queryArgs = (rest[0] ?? {}) as unknown as PaginatedQueryArgs<F>,
      pageSize = rest[1]?.pageSize ?? DEFAULT_PAGE_SIZE,
      { loadMore, results, status } = usePaginatedQuery(query, queryArgs, { initialNumItems: pageSize }),
      subIdRef = useRef<number>(0)

    useEffect(() => {
      if (!isDev) return
      const queryName = typeof query === 'string' ? query : ((query as { _name?: string })._name ?? 'unknown')
      subIdRef.current = trackSubscription(queryName, queryArgs as Record<string, unknown>)
      const id = subIdRef.current
      return () => untrackSubscription(id)
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [])

    useEffect(() => {
      if (!(isDev && subIdRef.current)) return
      const devStatus =
        status === 'LoadingFirstPage'
          ? 'loading'
          : status === 'Exhausted' || status === 'CanLoadMore'
            ? 'loaded'
            : 'loading'
      updateSubscription(subIdRef.current, devStatus)
    }, [status, results])

    return {
      isDone: status === 'Exhausted',
      items: results as ListItems<F>,
      loadMore: (n?: number) => loadMore(n ?? pageSize),
      status
    }
  }

export type { UseListOptions }
export { DEFAULT_PAGE_SIZE, useList }

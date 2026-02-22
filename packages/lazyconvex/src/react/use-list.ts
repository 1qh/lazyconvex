'use client'

import type { PaginatedQueryArgs, PaginatedQueryReference } from 'convex/react'
import type { FunctionReturnType } from 'convex/server'

import { usePaginatedQuery } from 'convex/react'

type ListItems<F extends PaginatedQueryReference> = FunctionReturnType<F>['page']

type ListRest<F extends PaginatedQueryReference> =
  PaginatedQueryArgs<F> extends Record<string, never>
    ? [args?: PaginatedQueryArgs<F>, options?: UseListOptions]
    : [args: PaginatedQueryArgs<F>, options?: UseListOptions]
interface UseListOptions {
  pageSize?: number
}
const DEFAULT_PAGE_SIZE = 50,
  useList = <F extends PaginatedQueryReference>(query: F, ...rest: ListRest<F>) => {
    const queryArgs = (rest[0] ?? {}) as unknown as PaginatedQueryArgs<F>,
      pageSize = rest[1]?.pageSize ?? DEFAULT_PAGE_SIZE,
      { loadMore, results, status } = usePaginatedQuery(query, queryArgs, { initialNumItems: pageSize })
    return {
      isDone: status === 'Exhausted',
      items: results as ListItems<F>,
      loadMore: (n?: number) => loadMore(n ?? pageSize),
      status
    }
  }

export type { UseListOptions }
export { DEFAULT_PAGE_SIZE, useList }

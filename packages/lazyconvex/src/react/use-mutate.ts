'use client'

import type { FunctionReference, FunctionReturnType, OptionalRestArgs } from 'convex/server'

import { useMutation } from 'convex/react'
import { useCallback } from 'react'

import type { MutationType } from './optimistic-store'

import { makeTempId, useOptimisticStore } from './optimistic-store'

interface MutateOptions {
  optimistic?: boolean
  type?: MutationType
}

type MutationRef = FunctionReference<'mutation'>

const detectMutationType = (ref: MutationRef): MutationType => {
    const name = typeof ref === 'string' ? ref : ((ref as { _name?: string })._name ?? '')
    if (name.endsWith(':rm') || name.endsWith('.rm') || name.includes('delete') || name.includes('remove')) return 'delete'
    if (name.endsWith(':update') || name.endsWith('.update') || name.includes('patch')) return 'update'
    return 'create'
  },
  useMutate = <T extends MutationRef>(
    ref: T,
    options?: MutateOptions
  ): ((args: OptionalRestArgs<T>[0]) => Promise<FunctionReturnType<T>>) => {
    const mutate = useMutation(ref),
      store = useOptimisticStore(),
      isOptimistic = options?.optimistic !== false

    return useCallback(
      async (args: OptionalRestArgs<T>[0]): Promise<FunctionReturnType<T>> => {
        const type = options?.type ?? detectMutationType(ref)

        if (!(store && isOptimistic)) 
          return (mutate as (a: OptionalRestArgs<T>[0]) => Promise<FunctionReturnType<T>>)(args)
        

        const tempId = makeTempId(),
          id = (args as Record<string, unknown>)?.id as string | undefined
        store.add({
          args: args as Record<string, unknown>,
          id: id ?? tempId,
          tempId,
          timestamp: Date.now(),
          type
        })

        try {
          const result = await (mutate as (a: OptionalRestArgs<T>[0]) => Promise<FunctionReturnType<T>>)(args)
          return result
        } finally {
          store.remove(tempId)
        }
      },
      [isOptimistic, mutate, options?.type, ref, store]
    )
  }

export type { MutateOptions }
export { useMutate }

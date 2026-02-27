'use client'

import { useMemo } from 'react'

import { createOptimisticStore, OptimisticContext } from './optimistic-store'

const OptimisticProvider = ({ children }: { children: React.ReactNode }) => {
  const store = useMemo(() => createOptimisticStore(), [])
  return <OptimisticContext value={store}>{children}</OptimisticContext>
}

export default OptimisticProvider

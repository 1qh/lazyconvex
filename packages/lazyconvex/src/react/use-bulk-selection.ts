/* oxlint-disable promise/prefer-await-to-then, promise/no-nesting */
'use client'

import { useState } from 'react'

import type { ToastFn } from './use-soft-delete'

import { UNDO_MS } from '../constants'

interface UseBulkSelectionOpts {
  bulkRm: (args: { ids: string[]; orgId: string }) => Promise<unknown>
  items: { _id: string }[]
  onError?: (error: unknown) => void
  onSuccess?: (count: number) => void
  orgId: string
  restore?: (args: { id: string }) => Promise<unknown>
  toast?: ToastFn
  undoLabel?: string
  undoMs?: number
}

const useBulkSelection = ({
  bulkRm,
  items,
  onError,
  onSuccess,
  orgId,
  restore,
  toast: t,
  undoLabel,
  undoMs = UNDO_MS
}: UseBulkSelectionOpts) => {
  const [selected, setSelected] = useState<Set<string>>(() => new Set()),
    clear = () => {
      setSelected(new Set<string>())
    },
    toggleSelect = (id: string) => {
      setSelected(prev => {
        const next = new Set(prev)
        if (next.has(id)) next.delete(id)
        else next.add(id)
        return next
      })
    },
    toggleSelectAll = () => {
      if (selected.size === items.length) setSelected(new Set<string>())
      else setSelected(new Set(items.map(i => i._id)))
    },
    handleBulkDelete = () => {
      if (selected.size === 0) return
      const ids = [...selected],
        count = ids.length
      bulkRm({ ids, orgId })
        .then(() => {
          setSelected(new Set<string>())
          if (t && restore) {
            const label = undoLabel ?? 'item'
            t(`${count} ${label}${count === 1 ? '' : 's'} deleted`, {
              action: {
                label: 'Undo',
                onClick: () => {
                  const run = async () => {
                    try {
                      await Promise.all(ids.map(async id => restore({ id })))
                      t(`${count} ${label}${count === 1 ? '' : 's'} restored`)
                    } catch (restoreError: unknown) {
                      if (onError) onError(restoreError)
                    }
                  }
                  run()
                }
              },
              duration: undoMs
            })
          } else onSuccess?.(count)
          return null
        })
        .catch((bulkError: unknown) => onError?.(bulkError))
    }

  return { clear, handleBulkDelete, selected, toggleSelect, toggleSelectAll }
}

export type { UseBulkSelectionOpts }
export { useBulkSelection }

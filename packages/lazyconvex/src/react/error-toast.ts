'use client'
import { useCallback } from 'react'

import type { ConvexErrorData, ErrorHandler } from '../server/helpers'

import { extractErrorData, getErrorMessage, handleConvexError } from '../server/helpers'

interface ErrorToastOptions {
  handlers?: ErrorHandler
  toast: ToastFn
}

type ToastFn = (message: string) => void

const useErrorToast = ({ handlers, toast }: ErrorToastOptions) =>
    useCallback(
      (error: unknown) => {
        const data = extractErrorData(error),
          code = data?.code,
          hasSpecificHandler = code ? Object.hasOwn(handlers ?? {}, code) : false
        if (hasSpecificHandler) {
          handleConvexError(error, handlers ?? {})
          return
        }
        const message = data?.message ?? getErrorMessage(error)
        toast(message)
      },
      [handlers, toast]
    ),
  makeErrorHandler = (toast: ToastFn, overrides?: Partial<Record<string, (data?: ConvexErrorData) => void>>) => {
    const handler: ErrorHandler = {
      ...overrides,
      default: () => {
        /* Noop */
      }
    }
    return (error: unknown) => {
      const data = extractErrorData(error),
        code = data?.code,
        hasOverride = code ? Object.hasOwn(overrides ?? {}, code) : false
      if (hasOverride) {
        handleConvexError(error, handler)
        return
      }
      toast(data?.message ?? getErrorMessage(error))
    }
  }

export type { ErrorToastOptions, ToastFn }
export { makeErrorHandler, useErrorToast }

/* eslint-disable @typescript-eslint/explicit-member-accessibility */
// biome-ignore-all lint/style/useReactFunctionComponents: x
'use client'

import type { ErrorInfo, ReactNode } from 'react'

import { Component } from 'react'

interface ErrorBoundaryProps {
  children: ReactNode
  fallback?: ReactNode
}
interface ErrorBoundaryState {
  hasError: boolean
}
// eslint-disable-next-line react/require-optimization
class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  // eslint-disable-next-line react/sort-comp
  constructor(props: ErrorBoundaryProps) {
    super(props)
    this.state = { hasError: false }
  }
  static getDerivedStateFromError(): ErrorBoundaryState {
    return { hasError: true }
  }
  // oxlint-disable-next-line class-methods-use-this
  // eslint-disable-next-line @typescript-eslint/class-methods-use-this
  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error(error, errorInfo) // eslint-disable-line no-console
  }
  // eslint-disable-next-line @typescript-eslint/promise-function-async
  render() {
    const { hasError } = this.state,
      { children, fallback } = this.props
    if (hasError)
      return (
        fallback ?? (
          <div className='flex min-h-screen items-center justify-center'>
            <div className='text-center'>
              <h1 className='mb-2 text-2xl font-bold'>Something went wrong</h1>
              <p className='text-muted-foreground'>Please refresh the page</p>
            </div>
          </div>
        )
      )
    return children
  }
}

export default ErrorBoundary

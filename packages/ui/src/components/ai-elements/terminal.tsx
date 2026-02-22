// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { ComponentProps, HTMLAttributes } from 'react'

import { cn } from '@a/ui'
import { Button } from '@a/ui/button'
import Ansi from 'ansi-to-react'
import { CheckIcon, CopyIcon, TerminalIcon, Trash2Icon } from 'lucide-react'
import { createContext, use, useEffect, useRef, useState } from 'react'

import { Shimmer } from './shimmer'

interface TerminalContextType {
  autoScroll: boolean
  isStreaming: boolean
  onClear?: () => void
  output: string
}

const TerminalContext = createContext<TerminalContextType>({
  autoScroll: true,
  isStreaming: false,
  output: ''
})

export type TerminalHeaderProps = HTMLAttributes<HTMLDivElement>

export const TerminalHeader = ({ children, className, ...props }: TerminalHeaderProps) => (
  <div className={cn('flex items-center justify-between border-b border-zinc-800 px-4 py-2', className)} {...props}>
    {children}
  </div>
)

export type TerminalTitleProps = HTMLAttributes<HTMLDivElement>

export const TerminalTitle = ({ children, className, ...props }: TerminalTitleProps) => (
  <div className={cn('flex items-center gap-2 text-sm text-zinc-400', className)} {...props}>
    <TerminalIcon className='size-4' />
    {children ?? 'Terminal'}
  </div>
)

export type TerminalStatusProps = HTMLAttributes<HTMLDivElement>

export const TerminalStatus = ({ children, className, ...props }: TerminalStatusProps) => {
  const { isStreaming } = use(TerminalContext)

  if (!isStreaming) return null

  return (
    <div className={cn('flex items-center gap-2 text-xs text-zinc-400', className)} {...props}>
      {children ?? <Shimmer className='w-16'>Streaming...</Shimmer>}
    </div>
  )
}

export type TerminalActionsProps = HTMLAttributes<HTMLDivElement>

export const TerminalActions = ({ children, className, ...props }: TerminalActionsProps) => (
  <div className={cn('flex items-center gap-1', className)} {...props}>
    {children}
  </div>
)

export type TerminalCopyButtonProps = ComponentProps<typeof Button> & {
  onCopy?: () => void
  onError?: (error: Error) => void
  timeout?: number
}

export const TerminalCopyButton = ({
  children,
  className,
  onCopy,
  onError,
  timeout = 2000,
  ...props
}: TerminalCopyButtonProps) => {
  const [isCopied, setIsCopied] = useState(false),
    { output } = use(TerminalContext),
    copyToClipboard = async () => {
      // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
      if (typeof window === 'undefined' || !navigator?.clipboard?.writeText) {
        onError?.(new Error('Clipboard API not available'))
        return
      }

      try {
        await navigator.clipboard.writeText(output)
        setIsCopied(true)
        onCopy?.()
        setTimeout(() => setIsCopied(false), timeout)
      } catch (error) {
        onError?.(error as Error)
      }
    },
    Icon = isCopied ? CheckIcon : CopyIcon

  return (
    <Button
      className={cn('size-7 shrink-0 text-zinc-400 hover:bg-zinc-800 hover:text-zinc-100', className)}
      // eslint-disable-next-line @typescript-eslint/strict-void-return
      onClick={copyToClipboard}
      size='icon'
      variant='ghost'
      {...props}>
      {children ?? <Icon size={14} />}
    </Button>
  )
}

export type TerminalClearButtonProps = ComponentProps<typeof Button>

export const TerminalClearButton = ({ children, className, ...props }: TerminalClearButtonProps) => {
  const { onClear } = use(TerminalContext)

  if (!onClear) return null

  return (
    <Button
      className={cn('size-7 shrink-0 text-zinc-400 hover:bg-zinc-800 hover:text-zinc-100', className)}
      onClick={onClear}
      size='icon'
      variant='ghost'
      {...props}>
      {children ?? <Trash2Icon size={14} />}
    </Button>
  )
}

export type TerminalContentProps = HTMLAttributes<HTMLDivElement>

export const TerminalContent = ({ children, className, ...props }: TerminalContentProps) => {
  const { autoScroll, isStreaming, output } = use(TerminalContext),
    containerRef = useRef<HTMLDivElement>(null)

  // biome-ignore lint/correctness/useExhaustiveDependencies: output triggers auto-scroll when new content arrives
  useEffect(() => {
    if (autoScroll && containerRef.current) containerRef.current.scrollTop = containerRef.current.scrollHeight
  }, [output, autoScroll])

  return (
    <div className={cn('max-h-96 overflow-auto p-4 font-mono text-sm/relaxed', className)} ref={containerRef} {...props}>
      {children ?? (
        <pre className='wrap-break-word whitespace-pre-wrap'>
          <Ansi>{output}</Ansi>
          {isStreaming ? <span className='ml-0.5 inline-block h-4 w-2 animate-pulse bg-zinc-100' /> : null}
        </pre>
      )}
    </div>
  )
}

export type TerminalProps = HTMLAttributes<HTMLDivElement> & {
  autoScroll?: boolean
  isStreaming?: boolean
  onClear?: () => void
  output: string
}

export const Terminal = ({
  autoScroll = true,
  children,
  className,
  isStreaming = false,
  onClear,
  output,
  ...props
}: TerminalProps) => (
  <TerminalContext value={{ autoScroll, isStreaming, onClear, output }}>
    <div className={cn('flex flex-col overflow-hidden rounded-lg border bg-zinc-950 text-zinc-100', className)} {...props}>
      {children ?? (
        <>
          <TerminalHeader>
            <TerminalTitle />
            <div className='flex items-center gap-1'>
              <TerminalStatus />
              <TerminalActions>
                <TerminalCopyButton />
                {onClear ? <TerminalClearButton /> : null}
              </TerminalActions>
            </div>
          </TerminalHeader>
          <TerminalContent />
        </>
      )}
    </div>
  </TerminalContext>
)

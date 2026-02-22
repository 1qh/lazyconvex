/* eslint-disable prefer-named-capture-group, complexity */
// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { ComponentProps } from 'react'

import { cn } from '@a/ui'
import { Button } from '@a/ui/button'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@a/ui/collapsible'
import { useControllableState } from '@radix-ui/react-use-controllable-state'
import { AlertTriangleIcon, CheckIcon, ChevronDownIcon, CopyIcon } from 'lucide-react'
import { createContext, memo, use, useMemo, useState } from 'react'

// Regex patterns for parsing stack traces
const STACK_FRAME_WITH_PARENS_REGEX = /^at\s+(.+?)\s+\((.+):(\d+):(\d+)\)$/u,
  STACK_FRAME_WITHOUT_FN_REGEX = /^at\s+(.+):(\d+):(\d+)$/u,
  ERROR_TYPE_REGEX = /^(\w+Error|Error):\s*(.*)$/u,
  AT_PREFIX_REGEX = /^at\s+/u

interface ParsedStackTrace {
  errorMessage: string
  errorType: null | string
  frames: StackFrame[]
  raw: string
}

interface StackFrame {
  columnNumber: null | number
  filePath: null | string
  functionName: null | string
  isInternal: boolean
  lineNumber: null | number
  raw: string
}

interface StackTraceContextValue {
  isOpen: boolean
  onFilePathClick?: (filePath: string, line?: number, column?: number) => void
  raw: string
  setIsOpen: (open: boolean) => void
  trace: ParsedStackTrace
}

const StackTraceContext = createContext<null | StackTraceContextValue>(null),
  useStackTrace = () => {
    const context = use(StackTraceContext)
    if (!context) throw new Error('StackTrace components must be used within StackTrace')

    return context
  },
  parseStackFrame = (line: string): StackFrame => {
    const trimmed = line.trim(),
      // Pattern: at functionName (filePath:line:column)
      withParensMatch = STACK_FRAME_WITH_PARENS_REGEX.exec(trimmed)
    if (withParensMatch) {
      const [, functionName, filePath, lineNum, colNum] = withParensMatch,
        isInternal = Boolean(
          filePath?.includes('node_modules') ?? filePath?.startsWith('node:') ?? filePath?.includes('internal/')
        )
      return {
        columnNumber: colNum ? Number.parseInt(colNum, 10) : null,
        filePath: filePath ?? null,
        functionName: functionName ?? null,
        isInternal,
        lineNumber: lineNum ? Number.parseInt(lineNum, 10) : null,
        raw: trimmed
      }
    }

    // Pattern: at filePath:line:column (no function name)
    const withoutFnMatch = STACK_FRAME_WITHOUT_FN_REGEX.exec(trimmed)
    if (withoutFnMatch) {
      const [, filePath, lineNum, colNum] = withoutFnMatch,
        isInternal =
          (filePath?.includes('node_modules') ?? false) ||
          (filePath?.startsWith('node:') ?? false) ||
          (filePath?.includes('internal/') ?? false)
      return {
        columnNumber: colNum ? Number.parseInt(colNum, 10) : null,
        filePath: filePath ?? null,
        functionName: null,
        isInternal,
        lineNumber: lineNum ? Number.parseInt(lineNum, 10) : null,
        raw: trimmed
      }
    }

    // Fallback: unparseable line
    return {
      columnNumber: null,
      filePath: null,
      functionName: null,
      isInternal: trimmed.includes('node_modules') || trimmed.includes('node:'),
      lineNumber: null,
      raw: trimmed
    }
  },
  parseStackTrace = (trace: string): ParsedStackTrace => {
    const lines = trace.split('\n').filter(line => line.trim())

    if (lines.length === 0)
      return {
        errorMessage: trace,
        errorType: null,
        frames: [],
        raw: trace
      }

    const firstLine = lines[0]?.trim() ?? ''
    let errorType: null | string = null,
      errorMessage = firstLine

    // Try to extract error type from "ErrorType: message" format
    const errorMatch = ERROR_TYPE_REGEX.exec(firstLine)
    if (errorMatch) {
      errorType = errorMatch[1] ?? null
      errorMessage = errorMatch[2] ?? ''
    }

    // Parse stack frames (lines starting with "at")
    const frames = lines
      .slice(1)
      .filter(line => line.trim().startsWith('at '))
      .map(parseStackFrame)

    return {
      errorMessage,
      errorType,
      frames,
      raw: trace
    }
  }

export type StackTraceProps = ComponentProps<'div'> & {
  defaultOpen?: boolean
  onFilePathClick?: (filePath: string, line?: number, column?: number) => void
  onOpenChange?: (open: boolean) => void
  open?: boolean
  trace: string
}

export const StackTrace = memo(
  ({
    children,
    className,
    defaultOpen = false,
    onFilePathClick,
    onOpenChange,
    open,
    trace,
    ...props
  }: StackTraceProps) => {
    const [isOpen, setIsOpen] = useControllableState({
        defaultProp: defaultOpen,
        onChange: onOpenChange,
        prop: open
      }),
      parsedTrace = useMemo(() => parseStackTrace(trace), [trace]),
      contextValue = useMemo(
        () => ({
          isOpen,
          onFilePathClick,
          raw: trace,
          setIsOpen,
          trace: parsedTrace
        }),
        [parsedTrace, trace, isOpen, setIsOpen, onFilePathClick]
      )

    return (
      <StackTraceContext value={contextValue}>
        <div
          className={cn('not-prose w-full overflow-hidden rounded-lg border bg-background font-mono text-sm', className)}
          {...props}>
          {children}
        </div>
      </StackTraceContext>
    )
  }
)

export type StackTraceHeaderProps = ComponentProps<typeof CollapsibleTrigger>

export const StackTraceHeader = memo(({ children, className, ...props }: StackTraceHeaderProps) => {
  const { isOpen, setIsOpen } = useStackTrace()

  return (
    <Collapsible onOpenChange={setIsOpen} open={isOpen}>
      <CollapsibleTrigger asChild {...props}>
        <div
          className={cn(
            'flex w-full cursor-pointer items-center gap-3 p-3 text-left transition-colors hover:bg-muted/50',
            className
          )}>
          {children}
        </div>
      </CollapsibleTrigger>
    </Collapsible>
  )
})

export type StackTraceErrorProps = ComponentProps<'div'>

export const StackTraceError = memo(({ children, className, ...props }: StackTraceErrorProps) => (
  <div className={cn('flex flex-1 items-center gap-2 overflow-hidden', className)} {...props}>
    <AlertTriangleIcon className='size-4 shrink-0 text-destructive' />
    {children}
  </div>
))

export type StackTraceErrorTypeProps = ComponentProps<'span'>

export const StackTraceErrorType = memo(({ children, className, ...props }: StackTraceErrorTypeProps) => {
  const { trace } = useStackTrace()

  return (
    <span className={cn('shrink-0 font-semibold text-destructive', className)} {...props}>
      {children ?? trace.errorType}
    </span>
  )
})

export type StackTraceErrorMessageProps = ComponentProps<'span'>

export const StackTraceErrorMessage = memo(({ children, className, ...props }: StackTraceErrorMessageProps) => {
  const { trace } = useStackTrace()

  return (
    <span className={cn('truncate text-foreground', className)} {...props}>
      {children ?? trace.errorMessage}
    </span>
  )
})

export type StackTraceActionsProps = ComponentProps<'div'>

export const StackTraceActions = memo(({ children, className, ...props }: StackTraceActionsProps) => (
  // biome-ignore lint/a11y/noNoninteractiveElementInteractions: stopPropagation required for nested interactions
  // biome-ignore lint/a11y/useSemanticElements: fieldset doesn't fit this UI pattern
  // oxlint-disable-next-line jsx_a11y/no-static-element-interactions
  <div
    className={cn('flex shrink-0 items-center gap-1', className)}
    onClick={e => e.stopPropagation()}
    onKeyDown={e => {
      if (e.key === 'Enter' || e.key === ' ') e.stopPropagation()
    }}
    role='group'
    {...props}>
    {children}
  </div>
))

export type StackTraceCopyButtonProps = ComponentProps<typeof Button> & {
  onCopy?: () => void
  onError?: (error: Error) => void
  timeout?: number
}

export const StackTraceCopyButton = memo(
  ({ children, className, onCopy, onError, timeout = 2000, ...props }: StackTraceCopyButtonProps) => {
    const [isCopied, setIsCopied] = useState(false),
      { raw } = useStackTrace(),
      copyToClipboard = async () => {
        // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
        if (typeof window === 'undefined' || !navigator?.clipboard?.writeText) {
          onError?.(new Error('Clipboard API not available'))
          return
        }

        try {
          await navigator.clipboard.writeText(raw)
          setIsCopied(true)
          onCopy?.()
          setTimeout(() => setIsCopied(false), timeout)
        } catch (error) {
          onError?.(error as Error)
        }
      },
      Icon = isCopied ? CheckIcon : CopyIcon

    return (
      // eslint-disable-next-line @typescript-eslint/strict-void-return
      <Button className={cn('size-7', className)} onClick={copyToClipboard} size='icon' variant='ghost' {...props}>
        {children ?? <Icon size={14} />}
      </Button>
    )
  }
)

export type StackTraceExpandButtonProps = ComponentProps<'div'>

export const StackTraceExpandButton = memo(({ className, ...props }: StackTraceExpandButtonProps) => {
  const { isOpen } = useStackTrace()

  return (
    <div className={cn('flex size-7 items-center justify-center', className)} {...props}>
      <ChevronDownIcon
        className={cn('size-4 text-muted-foreground transition-transform', isOpen ? 'rotate-180' : 'rotate-0')}
      />
    </div>
  )
})

export type StackTraceContentProps = ComponentProps<typeof CollapsibleContent> & {
  maxHeight?: number
}

export const StackTraceContent = memo(({ children, className, maxHeight = 400, ...props }: StackTraceContentProps) => {
  const { isOpen } = useStackTrace()

  return (
    <Collapsible open={isOpen}>
      <CollapsibleContent
        className={cn(
          'overflow-auto border-t bg-muted/30',
          'data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0',
          className
        )}
        style={{ maxHeight }}
        {...props}>
        {children}
      </CollapsibleContent>
    </Collapsible>
  )
})

export type StackTraceFramesProps = ComponentProps<'div'> & {
  showInternalFrames?: boolean
}

export const StackTraceFrames = memo(({ className, showInternalFrames = true, ...props }: StackTraceFramesProps) => {
  const { onFilePathClick, trace } = useStackTrace(),
    framesToShow = showInternalFrames ? trace.frames : trace.frames.filter(f => !f.isInternal)

  return (
    <div className={cn('space-y-1 p-3', className)} {...props}>
      {framesToShow.map((frame, index) => (
        <div
          className={cn('text-xs', frame.isInternal ? 'text-muted-foreground/50' : 'text-foreground/90')}
          key={`${frame.raw}-${index}`}>
          <span className='text-muted-foreground'>at </span>
          {frame.functionName ? (
            <span className={frame.isInternal ? '' : 'text-foreground'}>{frame.functionName} </span>
          ) : null}
          {frame.filePath ? (
            <>
              <span className='text-muted-foreground'>(</span>
              <button
                className={cn('underline decoration-dotted hover:text-primary', onFilePathClick && 'cursor-pointer')}
                disabled={!onFilePathClick}
                onClick={() => {
                  if (frame.filePath)
                    onFilePathClick?.(frame.filePath, frame.lineNumber ?? undefined, frame.columnNumber ?? undefined)
                }}
                type='button'>
                {frame.filePath}
                {frame.lineNumber !== null && `:${frame.lineNumber}`}
                {frame.columnNumber !== null && `:${frame.columnNumber}`}
              </button>
              <span className='text-muted-foreground'>)</span>
            </>
          ) : null}
          {!(frame.filePath ?? frame.functionName) && <span>{frame.raw.replace(AT_PREFIX_REGEX, '')}</span>}
        </div>
      ))}
      {framesToShow.length === 0 && <div className='text-xs text-muted-foreground'>No stack frames</div>}
    </div>
  )
})

StackTrace.displayName = 'StackTrace'
StackTraceHeader.displayName = 'StackTraceHeader'
StackTraceError.displayName = 'StackTraceError'
StackTraceErrorType.displayName = 'StackTraceErrorType'
StackTraceErrorMessage.displayName = 'StackTraceErrorMessage'
StackTraceActions.displayName = 'StackTraceActions'
StackTraceCopyButton.displayName = 'StackTraceCopyButton'
StackTraceExpandButton.displayName = 'StackTraceExpandButton'
StackTraceContent.displayName = 'StackTraceContent'
StackTraceFrames.displayName = 'StackTraceFrames'

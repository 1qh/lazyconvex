/* eslint-disable max-statements */
// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { ComponentProps, HTMLAttributes } from 'react'

import { cn } from '@a/ui'
import { Badge } from '@a/ui/badge'
import { Button } from '@a/ui/button'
import { Switch } from '@a/ui/switch'
import { CheckIcon, CopyIcon, EyeIcon, EyeOffIcon } from 'lucide-react'
import { createContext, use, useState } from 'react'

interface EnvironmentVariablesContextType {
  setShowValues: (show: boolean) => void
  showValues: boolean
}

const EnvironmentVariablesContext = createContext<EnvironmentVariablesContextType>({
  setShowValues: () => {
    //
  },
  showValues: false
})

export type EnvironmentVariablesProps = HTMLAttributes<HTMLDivElement> & {
  defaultShowValues?: boolean
  onShowValuesChange?: (show: boolean) => void
  showValues?: boolean
}

export const EnvironmentVariables = ({
  children,
  className,
  defaultShowValues,
  onShowValuesChange,
  showValues: controlledShowValues,
  ...props
}: EnvironmentVariablesProps) => {
  const [internalShowValues, setInternalShowValues] = useState(defaultShowValues),
    showValues = Boolean(controlledShowValues ?? internalShowValues),
    setShowValues = (show: boolean) => {
      setInternalShowValues(show)
      onShowValuesChange?.(show)
    }

  return (
    <EnvironmentVariablesContext value={{ setShowValues, showValues }}>
      <div className={cn('rounded-lg border bg-background', className)} {...props}>
        {children}
      </div>
    </EnvironmentVariablesContext>
  )
}

export type EnvironmentVariablesHeaderProps = HTMLAttributes<HTMLDivElement>

export const EnvironmentVariablesHeader = ({ children, className, ...props }: EnvironmentVariablesHeaderProps) => (
  <div className={cn('flex items-center justify-between border-b px-4 py-3', className)} {...props}>
    {children}
  </div>
)

export type EnvironmentVariablesTitleProps = HTMLAttributes<HTMLHeadingElement>

export const EnvironmentVariablesTitle = ({ children, className, ...props }: EnvironmentVariablesTitleProps) => (
  <h3 className={cn('text-sm font-medium', className)} {...props}>
    {children ?? 'Environment Variables'}
  </h3>
)

export type EnvironmentVariablesToggleProps = ComponentProps<typeof Switch>

export const EnvironmentVariablesToggle = ({ className, ...props }: EnvironmentVariablesToggleProps) => {
  const { setShowValues, showValues } = use(EnvironmentVariablesContext)

  return (
    <div className={cn('flex items-center gap-2', className)}>
      <span className='text-xs text-muted-foreground'>
        {showValues ? <EyeIcon size={14} /> : <EyeOffIcon size={14} />}
      </span>
      <Switch aria-label='Toggle value visibility' checked={showValues} onCheckedChange={setShowValues} {...props} />
    </div>
  )
}

export type EnvironmentVariablesContentProps = HTMLAttributes<HTMLDivElement>

export const EnvironmentVariablesContent = ({ children, className, ...props }: EnvironmentVariablesContentProps) => (
  <div className={cn('divide-y', className)} {...props}>
    {children}
  </div>
)

interface EnvironmentVariableContextType {
  name: string
  value: string
}

const EnvironmentVariableContext = createContext<EnvironmentVariableContextType>({
  name: '',
  value: ''
})

export type EnvironmentVariableNameProps = HTMLAttributes<HTMLSpanElement>

export const EnvironmentVariableName = ({ children, className, ...props }: EnvironmentVariableNameProps) => {
  const { name } = use(EnvironmentVariableContext)

  return (
    <span className={cn('font-mono text-sm', className)} {...props}>
      {children ?? name}
    </span>
  )
}

export type EnvironmentVariableGroupProps = HTMLAttributes<HTMLDivElement>

export const EnvironmentVariableGroup = ({ children, className, ...props }: EnvironmentVariableGroupProps) => (
  <div className={cn('flex items-center gap-2', className)} {...props}>
    {children}
  </div>
)

export type EnvironmentVariableValueProps = HTMLAttributes<HTMLSpanElement>

export const EnvironmentVariableValue = ({ children, className, ...props }: EnvironmentVariableValueProps) => {
  const { value } = use(EnvironmentVariableContext),
    { showValues } = use(EnvironmentVariablesContext),
    displayValue = showValues ? value : '•'.repeat(Math.min(value.length, 20))

  return (
    <span className={cn('font-mono text-sm text-muted-foreground', !showValues && 'select-none', className)} {...props}>
      {children ?? displayValue}
    </span>
  )
}

export type EnvironmentVariableCopyButtonProps = ComponentProps<typeof Button> & {
  copyFormat?: 'export' | 'name' | 'value'
  onCopy?: () => void
  onError?: (error: Error) => void
  timeout?: number
}

export const EnvironmentVariableCopyButton = ({
  children,
  className,
  copyFormat = 'value',
  onCopy,
  onError,
  timeout = 2000,
  ...props
}: EnvironmentVariableCopyButtonProps) => {
  const [isCopied, setIsCopied] = useState(false),
    { name, value } = use(EnvironmentVariableContext),
    copyToClipboard = async () => {
      // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
      if (typeof window === 'undefined' || !navigator?.clipboard?.writeText) {
        onError?.(new Error('Clipboard API not available'))
        return
      }

      let textToCopy = value
      if (copyFormat === 'name') textToCopy = name
      else if (copyFormat === 'export') textToCopy = `export ${name}="${value}"`

      try {
        await navigator.clipboard.writeText(textToCopy)
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
    <Button className={cn('size-6 shrink-0', className)} onClick={copyToClipboard} size='icon' variant='ghost' {...props}>
      {children ?? <Icon size={12} />}
    </Button>
  )
}

export type EnvironmentVariableRequiredProps = ComponentProps<typeof Badge>

export const EnvironmentVariableRequired = ({ children, className, ...props }: EnvironmentVariableRequiredProps) => (
  <Badge className={cn('text-xs', className)} variant='secondary' {...props}>
    {children ?? 'Required'}
  </Badge>
)

export type EnvironmentVariableProps = HTMLAttributes<HTMLDivElement> & {
  name: string
  value: string
}

export const EnvironmentVariable = ({ children, className, name, value, ...props }: EnvironmentVariableProps) => (
  <EnvironmentVariableContext value={{ name, value }}>
    <div className={cn('flex items-center justify-between gap-4 px-4 py-3', className)} {...props}>
      {children ?? (
        <>
          <div className='flex items-center gap-2'>
            <EnvironmentVariableName />
          </div>
          <EnvironmentVariableValue />
        </>
      )}
    </div>
  </EnvironmentVariableContext>
)

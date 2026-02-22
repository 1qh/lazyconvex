// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { ComponentProps } from 'react'

import { cn } from '@a/ui'
import { InputGroup, InputGroupAddon, InputGroupButton, InputGroupInput, InputGroupText } from '@a/ui/input-group'
import { CheckIcon, CopyIcon } from 'lucide-react'
import { createContext, use, useEffect, useRef, useState } from 'react'

interface SnippetContextType {
  code: string
}

const SnippetContext = createContext<SnippetContextType>({
  code: ''
})

export type SnippetProps = ComponentProps<typeof InputGroup> & {
  code: string
}

export const Snippet = ({ children, className, code, ...props }: SnippetProps) => (
  <SnippetContext value={{ code }}>
    <InputGroup className={cn('font-mono', className)} {...props}>
      {children}
    </InputGroup>
  </SnippetContext>
)

export type SnippetAddonProps = ComponentProps<typeof InputGroupAddon>

export const SnippetAddon = (props: SnippetAddonProps) => <InputGroupAddon {...props} />

export type SnippetTextProps = ComponentProps<typeof InputGroupText>

export const SnippetText = ({ className, ...props }: SnippetTextProps) => (
  <InputGroupText className={cn('pl-2 font-normal text-muted-foreground', className)} {...props} />
)

export type SnippetInputProps = Omit<ComponentProps<typeof InputGroupInput>, 'readOnly' | 'value'>

export const SnippetInput = ({ className, ...props }: SnippetInputProps) => {
  const { code } = use(SnippetContext)

  return <InputGroupInput className={cn('text-foreground', className)} readOnly value={code} {...props} />
}

export type SnippetCopyButtonProps = ComponentProps<typeof InputGroupButton> & {
  onCopy?: () => void
  onError?: (error: Error) => void
  timeout?: number
}

export const SnippetCopyButton = ({
  children,
  className,
  onCopy,
  onError,
  timeout = 2000,
  ...props
}: SnippetCopyButtonProps) => {
  const [isCopied, setIsCopied] = useState(false),
    timeoutRef = useRef<number>(0),
    { code } = use(SnippetContext),
    copyToClipboard = async () => {
      // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
      if (typeof window === 'undefined' || !navigator?.clipboard?.writeText) {
        onError?.(new Error('Clipboard API not available'))
        return
      }

      try {
        if (!isCopied) {
          await navigator.clipboard.writeText(code)
          setIsCopied(true)
          onCopy?.()
          timeoutRef.current = globalThis.setTimeout(() => setIsCopied(false), timeout) as unknown as number
        }
      } catch (error) {
        onError?.(error as Error)
      }
    }

  useEffect(
    () => () => {
      globalThis.clearTimeout(timeoutRef.current)
    },
    []
  )

  const Icon = isCopied ? CheckIcon : CopyIcon

  return (
    <InputGroupButton
      aria-label='Copy'
      className={className}
      // eslint-disable-next-line @typescript-eslint/strict-void-return
      onClick={copyToClipboard}
      size='icon-sm'
      title='Copy'
      {...props}>
      {children ?? <Icon className='size-3.5' size={14} />}
    </InputGroupButton>
  )
}

// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { ComponentProps } from 'react'

import { cn } from '@a/ui'
import { Button } from '@a/ui/button'
import { ScrollArea, ScrollBar } from '@a/ui/scroll-area'

export type SuggestionsProps = ComponentProps<typeof ScrollArea>

export const Suggestions = ({ children, className, ...props }: SuggestionsProps) => (
  <ScrollArea className='w-full overflow-x-auto whitespace-nowrap' {...props}>
    <div className={cn('flex w-max flex-nowrap items-center gap-2', className)}>{children}</div>
    <ScrollBar className='hidden' orientation='horizontal' />
  </ScrollArea>
)

export type SuggestionProps = Omit<ComponentProps<typeof Button>, 'onClick'> & {
  onClick?: (suggestion: string) => void
  suggestion: string
}

export const Suggestion = ({
  children,
  className,
  onClick,
  size = 'sm',
  suggestion,
  variant = 'outline',
  ...props
}: SuggestionProps) => {
  const handleClick = () => {
    onClick?.(suggestion)
  }

  return (
    <Button
      className={cn('cursor-pointer rounded-full px-4', className)}
      onClick={handleClick}
      size={size}
      type='button'
      variant={variant}
      {...props}>
      {children ?? suggestion}
    </Button>
  )
}

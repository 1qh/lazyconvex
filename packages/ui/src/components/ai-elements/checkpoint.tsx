/* eslint-disable @typescript-eslint/promise-function-async */
'use client'

import type { LucideProps } from 'lucide-react'
import type { ComponentProps, HTMLAttributes } from 'react'

import { cn } from '@a/ui'
import { Button } from '@a/ui/button'
import { Separator } from '@a/ui/separator'
import { Tooltip, TooltipContent, TooltipTrigger } from '@a/ui/tooltip'
import { BookmarkIcon } from 'lucide-react'

export type CheckpointProps = HTMLAttributes<HTMLDivElement>

export const Checkpoint = ({ children, className, ...props }: CheckpointProps) => (
  <div className={cn('flex items-center gap-0.5 overflow-hidden text-muted-foreground', className)} {...props}>
    {children}
    <Separator />
  </div>
)

export type CheckpointIconProps = LucideProps

export const CheckpointIcon = ({ children, className, ...props }: CheckpointIconProps) =>
  children ?? <BookmarkIcon className={cn('size-4 shrink-0', className)} {...props} />

export type CheckpointTriggerProps = ComponentProps<typeof Button> & {
  tooltip?: string
}

export const CheckpointTrigger = ({
  children,
  size = 'sm',
  tooltip,
  variant = 'ghost',
  ...props
}: CheckpointTriggerProps) =>
  tooltip ? (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button size={size} type='button' variant={variant} {...props}>
          {children}
        </Button>
      </TooltipTrigger>
      <TooltipContent align='start' side='bottom'>
        {tooltip}
      </TooltipContent>
    </Tooltip>
  ) : (
    <Button size={size} type='button' variant={variant} {...props}>
      {children}
    </Button>
  )

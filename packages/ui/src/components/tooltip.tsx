'use client'

import { cn } from '@a/ui'
import { Tooltip as TooltipPrimitive } from 'radix-ui'

const TooltipProvider = ({ delayDuration = 0, ...props }: React.ComponentProps<typeof TooltipPrimitive.Provider>) => (
    <TooltipPrimitive.Provider data-slot='tooltip-provider' delayDuration={delayDuration} {...props} />
  ),
  Tooltip = ({ ...props }: React.ComponentProps<typeof TooltipPrimitive.Root>) => (
    <TooltipProvider>
      <TooltipPrimitive.Root data-slot='tooltip' {...props} />
    </TooltipProvider>
  ),
  TooltipTrigger = ({ ...props }: React.ComponentProps<typeof TooltipPrimitive.Trigger>) => (
    <TooltipPrimitive.Trigger data-slot='tooltip-trigger' {...props} />
  ),
  TooltipContent = ({
    children,
    className,
    sideOffset = 0,
    ...props
  }: React.ComponentProps<typeof TooltipPrimitive.Content>) => (
    <TooltipPrimitive.Portal>
      <TooltipPrimitive.Content
        className={cn(
          'z-50 w-fit origin-(--radix-tooltip-content-transform-origin) animate-in rounded-md bg-foreground px-3 py-1.5 text-xs text-balance text-background fade-in-0 zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95',
          className
        )}
        data-slot='tooltip-content'
        sideOffset={sideOffset}
        {...props}>
        {children}
        <TooltipPrimitive.Arrow className='z-50 size-2.5 translate-y-[calc(-50%-2px)] rotate-45 rounded-[2px] bg-foreground fill-foreground' />
      </TooltipPrimitive.Content>
    </TooltipPrimitive.Portal>
  )

export { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger }

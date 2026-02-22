'use client'

import { cn } from '@a/ui'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@a/ui/dialog'
import { Command as CommandPrimitive } from 'cmdk'
import { SearchIcon } from 'lucide-react'

const Command = ({ className, ...props }: React.ComponentProps<typeof CommandPrimitive>) => (
    <CommandPrimitive
      className={cn('flex size-full flex-col overflow-hidden rounded-md bg-popover text-popover-foreground', className)}
      data-slot='command'
      {...props}
    />
  ),
  CommandDialog = ({
    children,
    className,
    description = 'Search for a command to run...',
    showCloseButton = true,
    title = 'Command Palette',
    ...props
  }: React.ComponentProps<typeof Dialog> & {
    className?: string
    description?: string
    showCloseButton?: boolean
    title?: string
  }) => (
    <Dialog {...props}>
      <DialogHeader className='sr-only'>
        <DialogTitle>{title}</DialogTitle>
        <DialogDescription>{description}</DialogDescription>
      </DialogHeader>
      <DialogContent className={cn('overflow-hidden p-0', className)} showCloseButton={showCloseButton}>
        <Command className='**:data-[slot=command-input-wrapper]:h-12 [&_[cmdk-group]:not([hidden])_~[cmdk-group]]:pt-0 [&_[cmdk-input-wrapper]_svg]:size-5 [&_[cmdk-item]_svg]:size-5 **:[[cmdk-group-heading]]:px-2 **:[[cmdk-group-heading]]:font-medium **:[[cmdk-group-heading]]:text-muted-foreground **:[[cmdk-group]]:px-2 **:[[cmdk-input]]:h-12 **:[[cmdk-item]]:px-2 **:[[cmdk-item]]:py-3'>
          {children}
        </Command>
      </DialogContent>
    </Dialog>
  ),
  CommandInput = ({ className, ...props }: React.ComponentProps<typeof CommandPrimitive.Input>) => (
    <div className='flex h-9 items-center gap-2 border-b px-3' data-slot='command-input-wrapper'>
      <SearchIcon className='size-4 shrink-0 opacity-50' />
      <CommandPrimitive.Input
        className={cn(
          'flex h-10 w-full rounded-md bg-transparent py-3 text-sm outline-hidden placeholder:text-muted-foreground disabled:cursor-not-allowed disabled:opacity-50',
          className
        )}
        data-slot='command-input'
        {...props}
      />
    </div>
  ),
  CommandList = ({ className, ...props }: React.ComponentProps<typeof CommandPrimitive.List>) => (
    <CommandPrimitive.List
      className={cn('max-h-[300px] scroll-py-1 overflow-x-hidden overflow-y-auto', className)}
      data-slot='command-list'
      {...props}
    />
  ),
  CommandEmpty = ({ ...props }: React.ComponentProps<typeof CommandPrimitive.Empty>) => (
    <CommandPrimitive.Empty className='py-6 text-center text-sm' data-slot='command-empty' {...props} />
  ),
  CommandGroup = ({ className, ...props }: React.ComponentProps<typeof CommandPrimitive.Group>) => (
    <CommandPrimitive.Group
      className={cn(
        'overflow-hidden p-1 text-foreground **:[[cmdk-group-heading]]:px-2 **:[[cmdk-group-heading]]:py-1.5 **:[[cmdk-group-heading]]:text-xs **:[[cmdk-group-heading]]:font-medium **:[[cmdk-group-heading]]:text-muted-foreground',
        className
      )}
      data-slot='command-group'
      {...props}
    />
  ),
  CommandSeparator = ({ className, ...props }: React.ComponentProps<typeof CommandPrimitive.Separator>) => (
    <CommandPrimitive.Separator
      className={cn('-mx-1 h-px bg-border', className)}
      data-slot='command-separator'
      {...props}
    />
  ),
  CommandItem = ({ className, ...props }: React.ComponentProps<typeof CommandPrimitive.Item>) => (
    <CommandPrimitive.Item
      className={cn(
        "relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-hidden select-none data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50 data-[selected=true]:bg-accent data-[selected=true]:text-accent-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground",
        className
      )}
      data-slot='command-item'
      {...props}
    />
  ),
  CommandShortcut = ({ className, ...props }: React.ComponentProps<'span'>) => (
    <span
      className={cn('ml-auto text-xs tracking-widest text-muted-foreground', className)}
      data-slot='command-shortcut'
      {...props}
    />
  )

export {
  Command,
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
  CommandShortcut
}

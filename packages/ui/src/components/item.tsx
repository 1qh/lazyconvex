import type { VariantProps } from 'class-variance-authority'

import { cn } from '@a/ui'
import { Separator } from '@a/ui/separator'
import { cva } from 'class-variance-authority'
import { Slot as SlotPrimitive } from 'radix-ui'

const ItemGroup = ({ className, ...props }: React.ComponentProps<'div'>) => (
    <div className={cn('group/item-group flex flex-col', className)} data-slot='item-group' role='list' {...props} />
  ),
  ItemSeparator = ({ className, ...props }: React.ComponentProps<typeof Separator>) => (
    <Separator className={cn('my-0', className)} data-slot='item-separator' orientation='horizontal' {...props} />
  ),
  itemVariants = cva(
    'group/item flex flex-wrap items-center rounded-md border border-transparent text-sm transition-colors duration-100 outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 [a]:transition-colors [a]:hover:bg-accent/50',
    {
      defaultVariants: {
        size: 'default',
        variant: 'default'
      },
      variants: {
        size: {
          default: 'gap-4 p-4',
          sm: 'gap-2.5 px-4 py-3'
        },
        variant: {
          default: 'bg-transparent',
          muted: 'bg-muted/50',
          outline: 'border-border'
        }
      }
    }
  ),
  Item = ({
    asChild = false,
    className,
    size = 'default',
    variant = 'default',
    ...props
  }: React.ComponentProps<'div'> & VariantProps<typeof itemVariants> & { asChild?: boolean }) => {
    const Comp = asChild ? SlotPrimitive.Slot : 'div'
    return (
      <Comp
        className={cn(itemVariants({ className, size, variant }))}
        data-size={size}
        data-slot='item'
        data-variant={variant}
        {...props}
      />
    )
  },
  itemMediaVariants = cva(
    'flex shrink-0 items-center justify-center gap-2 group-has-data-[slot=item-description]/item:translate-y-0.5 group-has-data-[slot=item-description]/item:self-start [&_svg]:pointer-events-none',
    {
      defaultVariants: {
        variant: 'default'
      },
      variants: {
        variant: {
          default: 'bg-transparent',
          icon: "size-8 rounded-sm border bg-muted [&_svg:not([class*='size-'])]:size-4",
          image: 'size-10 overflow-hidden rounded-sm [&_img]:size-full [&_img]:object-cover'
        }
      }
    }
  ),
  ItemMedia = ({
    className,
    variant = 'default',
    ...props
  }: React.ComponentProps<'div'> & VariantProps<typeof itemMediaVariants>) => (
    <div
      className={cn(itemMediaVariants({ className, variant }))}
      data-slot='item-media'
      data-variant={variant}
      {...props}
    />
  ),
  ItemContent = ({ className, ...props }: React.ComponentProps<'div'>) => (
    <div
      className={cn('flex flex-1 flex-col gap-1 [&+[data-slot=item-content]]:flex-none', className)}
      data-slot='item-content'
      {...props}
    />
  ),
  ItemTitle = ({ className, ...props }: React.ComponentProps<'div'>) => (
    <div
      className={cn('flex w-fit items-center gap-2 text-sm/snug font-medium', className)}
      data-slot='item-title'
      {...props}
    />
  ),
  ItemDescription = ({ className, ...props }: React.ComponentProps<'p'>) => (
    <p
      className={cn(
        'line-clamp-2 text-sm/normal font-normal text-balance text-muted-foreground',
        '[&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary',
        className
      )}
      data-slot='item-description'
      {...props}
    />
  ),
  ItemActions = ({ className, ...props }: React.ComponentProps<'div'>) => (
    <div className={cn('flex items-center gap-2', className)} data-slot='item-actions' {...props} />
  ),
  ItemHeader = ({ className, ...props }: React.ComponentProps<'div'>) => (
    <div
      className={cn('flex basis-full items-center justify-between gap-2', className)}
      data-slot='item-header'
      {...props}
    />
  ),
  ItemFooter = ({ className, ...props }: React.ComponentProps<'div'>) => (
    <div
      className={cn('flex basis-full items-center justify-between gap-2', className)}
      data-slot='item-footer'
      {...props}
    />
  )

export {
  Item,
  ItemActions,
  ItemContent,
  ItemDescription,
  ItemFooter,
  ItemGroup,
  ItemHeader,
  ItemMedia,
  ItemSeparator,
  ItemTitle
}

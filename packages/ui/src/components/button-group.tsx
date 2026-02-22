import type { VariantProps } from 'class-variance-authority'

import { cn } from '@a/ui'
import { Separator } from '@a/ui/separator'
import { cva } from 'class-variance-authority'
import { Slot as SlotPrimitive } from 'radix-ui'

const buttonGroupVariants = cva(
    "flex w-fit items-stretch *:focus-visible:relative *:focus-visible:z-10 has-[>[data-slot=button-group]]:gap-2 has-[select[aria-hidden=true]:last-child]:[&>[data-slot=select-trigger]:last-of-type]:rounded-r-md [&>[data-slot=select-trigger]:not([class*='w-'])]:w-fit [&>input]:flex-1",
    {
      defaultVariants: {
        orientation: 'horizontal'
      },
      variants: {
        orientation: {
          horizontal:
            '[&>*:not(:first-child)]:rounded-l-none [&>*:not(:first-child)]:border-l-0 [&>*:not(:last-child)]:rounded-r-none',
          vertical:
            'flex-col [&>*:not(:first-child)]:rounded-t-none [&>*:not(:first-child)]:border-t-0 [&>*:not(:last-child)]:rounded-b-none'
        }
      }
    }
  ),
  ButtonGroup = ({
    className,
    orientation,
    ...props
  }: React.ComponentProps<'div'> & VariantProps<typeof buttonGroupVariants>) => (
    <div
      className={cn(buttonGroupVariants({ orientation }), className)}
      data-orientation={orientation}
      data-slot='button-group'
      role='group'
      {...props}
    />
  ),
  ButtonGroupText = ({
    asChild = false,
    className,
    ...props
  }: React.ComponentProps<'div'> & {
    asChild?: boolean
  }) => {
    const Comp = asChild ? SlotPrimitive.Slot : 'div'

    return (
      <Comp
        className={cn(
          "flex items-center gap-2 rounded-md border bg-muted px-4 text-sm font-medium shadow-xs [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4",
          className
        )}
        {...props}
      />
    )
  },
  ButtonGroupSeparator = ({ className, orientation = 'vertical', ...props }: React.ComponentProps<typeof Separator>) => (
    <Separator
      className={cn('relative m-0! self-stretch bg-input data-[orientation=vertical]:h-auto', className)}
      data-slot='button-group-separator'
      orientation={orientation}
      {...props}
    />
  )

export { ButtonGroup, ButtonGroupSeparator, ButtonGroupText, buttonGroupVariants }

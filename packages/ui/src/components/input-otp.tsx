'use client'

import { cn } from '@a/ui'
import { OTPInput, OTPInputContext } from 'input-otp'
import { MinusIcon } from 'lucide-react'
import * as React from 'react'

const InputOTP = ({
    className,
    containerClassName,
    ...props
  }: React.ComponentProps<typeof OTPInput> & {
    containerClassName?: string
  }) => (
    <OTPInput
      className={cn('disabled:cursor-not-allowed', className)}
      containerClassName={cn('flex items-center gap-2 has-disabled:opacity-50', containerClassName)}
      data-slot='input-otp'
      {...props}
    />
  ),
  InputOTPGroup = ({ className, ...props }: React.ComponentProps<'div'>) => (
    <div className={cn('flex items-center', className)} data-slot='input-otp-group' {...props} />
  ),
  InputOTPSlot = ({
    className,
    index,
    ...props
  }: React.ComponentProps<'div'> & {
    index: number
  }) => {
    const inputOTPContext = React.use(OTPInputContext),
      { char, hasFakeCaret, isActive } = inputOTPContext.slots[index] ?? {}

    return (
      <div
        className={cn(
          'relative flex size-9 items-center justify-center border-y border-r border-input text-sm shadow-xs transition-all outline-none first:rounded-l-md first:border-l last:rounded-r-md aria-invalid:border-destructive data-[active=true]:z-10 data-[active=true]:border-ring data-[active=true]:ring-[3px] data-[active=true]:ring-ring/50 data-[active=true]:aria-invalid:border-destructive data-[active=true]:aria-invalid:ring-destructive/20 dark:bg-input/30 dark:data-[active=true]:aria-invalid:ring-destructive/40',
          className
        )}
        data-active={isActive}
        data-slot='input-otp-slot'
        {...props}>
        {char}
        {hasFakeCaret ? (
          <div className='pointer-events-none absolute inset-0 flex items-center justify-center'>
            <div className='h-4 w-px animate-caret-blink bg-foreground duration-1000' />
          </div>
        ) : null}
      </div>
    )
  },
  InputOTPSeparator = ({ ...props }: React.ComponentProps<'div'>) => (
    <div data-slot='input-otp-separator' role='separator' {...props}>
      <MinusIcon />
    </div>
  )

export { InputOTP, InputOTPGroup, InputOTPSeparator, InputOTPSlot }

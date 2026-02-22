/* eslint-disable @eslint-react/no-array-index-key */
'use client'

import type { VariantProps } from 'class-variance-authority'

import { cn } from '@a/ui'
import { Label } from '@a/ui/label'
import { Separator } from '@a/ui/separator'
import { cva } from 'class-variance-authority'
import { useMemo } from 'react'

const FieldSet = ({ className, ...props }: React.ComponentProps<'fieldset'>) => (
    <fieldset
      className={cn(
        'flex flex-col gap-6',
        'has-[>[data-slot=checkbox-group]]:gap-3 has-[>[data-slot=radio-group]]:gap-3',
        className
      )}
      data-slot='field-set'
      {...props}
    />
  ),
  FieldLegend = ({ className, variant, ...props }: React.ComponentProps<'legend'> & { variant?: 'label' | 'legend' }) => (
    <legend
      className={cn('mb-3 font-medium', 'data-[variant=legend]:text-base', 'data-[variant=label]:text-sm', className)}
      data-slot='field-legend'
      data-variant={variant}
      {...props}
    />
  ),
  FieldGroup = ({ className, ...props }: React.ComponentProps<'div'>) => (
    <div
      className={cn(
        'group/field-group @container/field-group flex w-full flex-col gap-7 data-[slot=checkbox-group]:gap-3 *:data-[slot=field-group]:gap-4',
        className
      )}
      data-slot='field-group'
      {...props}
    />
  ),
  fieldVariants = cva('group/field flex w-full gap-3 data-[invalid=true]:text-destructive', {
    defaultVariants: {
      orientation: 'vertical'
    },
    variants: {
      orientation: {
        horizontal: [
          'flex-row items-center',
          '*:data-[slot=field-label]:flex-auto',
          'has-[>[data-slot=field-content]]:items-start has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px'
        ],
        responsive: [
          'flex-col *:w-full @md/field-group:flex-row @md/field-group:items-center @md/field-group:*:w-auto [&>.sr-only]:w-auto',
          '@md/field-group:*:data-[slot=field-label]:flex-auto',
          '@md/field-group:has-[>[data-slot=field-content]]:items-start @md/field-group:has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px'
        ],
        vertical: ['flex-col *:w-full [&>.sr-only]:w-auto']
      }
    }
  }),
  Field = ({ className, orientation, ...props }: React.ComponentProps<'div'> & VariantProps<typeof fieldVariants>) => (
    <div
      className={cn(fieldVariants({ orientation }), className)}
      data-orientation={orientation}
      data-slot='field'
      role='group'
      {...props}
    />
  ),
  FieldContent = ({ className, ...props }: React.ComponentProps<'div'>) => (
    <div
      className={cn('group/field-content flex flex-1 flex-col gap-1.5 leading-snug', className)}
      data-slot='field-content'
      {...props}
    />
  ),
  FieldLabel = ({ className, ...props }: React.ComponentProps<typeof Label>) => (
    <Label
      className={cn(
        'group/field-label peer/field-label flex w-fit gap-2 leading-snug group-data-[disabled=true]/field:opacity-50',
        'has-[>[data-slot=field]]:w-full has-[>[data-slot=field]]:flex-col has-[>[data-slot=field]]:rounded-md has-[>[data-slot=field]]:border *:data-[slot=field]:p-4',
        'has-data-[state=checked]:border-primary has-data-[state=checked]:bg-primary/5 dark:has-data-[state=checked]:bg-primary/10',
        className
      )}
      data-slot='field-label'
      {...props}
    />
  ),
  FieldTitle = ({ className, ...props }: React.ComponentProps<'div'>) => (
    <div
      className={cn(
        'flex w-fit items-center gap-2 text-sm/snug font-medium group-data-[disabled=true]/field:opacity-50',
        className
      )}
      data-slot='field-label'
      {...props}
    />
  ),
  FieldDescription = ({ className, ...props }: React.ComponentProps<'p'>) => (
    <p
      className={cn(
        'text-sm/normal font-normal text-muted-foreground group-has-data-[orientation=horizontal]/field:text-balance',
        'last:mt-0 nth-last-2:-mt-1 [[data-variant=legend]+&]:-mt-1.5',
        '[&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary',
        className
      )}
      data-slot='field-description'
      {...props}
    />
  ),
  FieldSeparator = ({
    children,
    className,
    ...props
  }: React.ComponentProps<'div'> & {
    children?: React.ReactNode
  }) => (
    <div
      className={cn('relative -my-2 h-5 text-sm group-data-[variant=outline]/field-group:-mb-2', className)}
      data-content={Boolean(children)}
      data-slot='field-separator'
      {...props}>
      <Separator className='absolute inset-0 top-1/2' />
      {children ? (
        <span
          className='relative mx-auto block w-fit bg-background px-2 text-muted-foreground'
          data-slot='field-separator-content'>
          {children}
        </span>
      ) : null}
    </div>
  ),
  FieldError = ({
    children,
    className,
    errors,
    ...props
  }: React.ComponentProps<'div'> & {
    errors?: (undefined | { message?: string })[]
  }) => {
    // eslint-disable-next-line react-hooks/use-memo
    const content = useMemo(async () => {
      if (children) return children

      if (!errors?.length) return null

      const uniqueErrors = [...new Map(errors.map(error => [error?.message, error])).values()]

      if (uniqueErrors.length === 1) return uniqueErrors[0]?.message

      return (
        <ul className='ml-4 flex list-disc flex-col gap-1'>
          {uniqueErrors.map((error, index) => error?.message && <li key={index}>{error.message}</li>)}
        </ul>
      )
    }, [children, errors])

    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition, @typescript-eslint/no-misused-promises
    if (!content) return null

    return (
      <div
        className={cn('text-sm font-normal text-destructive', className)}
        data-slot='field-error'
        role='alert'
        {...props}>
        {content}
      </div>
    )
  }

export {
  Field,
  FieldContent,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  FieldLegend,
  FieldSeparator,
  FieldSet,
  FieldTitle
}

'use client'

import type { Label as LabelPrimitive } from 'radix-ui'
import type { ControllerProps, FieldPath, FieldValues } from 'react-hook-form'

import { cn } from '@a/ui'
import { Label } from '@a/ui/label'
import { Slot as SlotPrimitive } from 'radix-ui'
import * as React from 'react'
import { Controller, FormProvider, useFormContext, useFormState } from 'react-hook-form'

const Form = FormProvider

interface FormFieldContextValue<
  TFieldValues extends FieldValues = FieldValues,
  TName extends FieldPath<TFieldValues> = FieldPath<TFieldValues>
> {
  name: TName
}

const FormFieldContext = React.createContext<FormFieldContextValue>({} as FormFieldContextValue),
  FormField = <
    TFieldValues extends FieldValues = FieldValues,
    TName extends FieldPath<TFieldValues> = FieldPath<TFieldValues>
  >({
    ...props
  }: ControllerProps<TFieldValues, TName>) => (
    <FormFieldContext value={{ name: props.name }}>
      <Controller {...props} />
    </FormFieldContext>
  ),
  FormItemContext = React.createContext<FormItemContextValue>({} as FormItemContextValue),
  FormItem = ({ className, ...props }: React.ComponentProps<'div'>) => {
    const id = React.useId()

    return (
      <FormItemContext value={{ id }}>
        <div className={cn('grid gap-2', className)} data-slot='form-item' {...props} />
      </FormItemContext>
    )
  },
  useFormField = () => {
    const fieldContext = React.use(FormFieldContext),
      itemContext = React.use(FormItemContext),
      { getFieldState } = useFormContext(),
      formState = useFormState({ name: fieldContext.name }),
      fieldState = getFieldState(fieldContext.name, formState)

    if (!fieldContext.name) throw new Error('useFormField should be used within <FormField>')

    const { id } = itemContext

    return {
      formDescriptionId: `${id}-form-item-description`,
      formItemId: `${id}-form-item`,
      formMessageId: `${id}-form-item-message`,
      id,
      name: fieldContext.name,
      ...fieldState
    }
  }

interface FormItemContextValue {
  id: string
}

const FormLabel = ({ className, ...props }: React.ComponentProps<typeof LabelPrimitive.Root>) => {
    const { error, formItemId } = useFormField()

    return (
      <Label
        className={cn('data-[error=true]:text-destructive', className)}
        data-error={Boolean(error)}
        data-slot='form-label'
        htmlFor={formItemId}
        {...props}
      />
    )
  },
  FormControl = ({ ...props }: React.ComponentProps<typeof SlotPrimitive.Slot>) => {
    const { error, formDescriptionId, formItemId, formMessageId } = useFormField()

    return (
      <SlotPrimitive.Slot
        aria-describedby={error ? `${formDescriptionId} ${formMessageId}` : formDescriptionId}
        aria-invalid={Boolean(error)}
        data-slot='form-control'
        id={formItemId}
        {...props}
      />
    )
  },
  FormDescription = ({ className, ...props }: React.ComponentProps<'p'>) => {
    const { formDescriptionId } = useFormField()

    return (
      <p
        className={cn('text-sm text-muted-foreground', className)}
        data-slot='form-description'
        id={formDescriptionId}
        {...props}
      />
    )
  },
  FormMessage = ({ className, ...props }: React.ComponentProps<'p'>) => {
    const { error, formMessageId } = useFormField(),
      body = error ? (error.message ?? '') : props.children

    if (!body) return null

    return (
      <p className={cn('text-sm text-destructive', className)} data-slot='form-message' id={formMessageId} {...props}>
        {body}
      </p>
    )
  }

export { Form, FormControl, FormDescription, FormField, FormItem, FormLabel, FormMessage, useFormField }

// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { ComponentProps } from 'react'

import { cn } from '@a/ui'
import { Button } from '@a/ui/button'
import { Card, CardAction, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@a/ui/card'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@a/ui/collapsible'
import { ChevronsUpDownIcon } from 'lucide-react'
import { createContext, use } from 'react'

import { Shimmer } from './shimmer'

interface PlanContextValue {
  isStreaming: boolean
}

const PlanContext = createContext<null | PlanContextValue>(null),
  usePlan = () => {
    const context = use(PlanContext)
    if (!context) throw new Error('Plan components must be used within Plan')

    return context
  }

export type PlanProps = ComponentProps<typeof Collapsible> & {
  isStreaming?: boolean
}

export const Plan = ({ children, className, isStreaming = false, ...props }: PlanProps) => (
  <PlanContext value={{ isStreaming }}>
    <Collapsible asChild data-slot='plan' {...props}>
      <Card className={cn('shadow-none', className)}>{children}</Card>
    </Collapsible>
  </PlanContext>
)

export type PlanHeaderProps = ComponentProps<typeof CardHeader>

export const PlanHeader = ({ className, ...props }: PlanHeaderProps) => (
  <CardHeader className={cn('flex items-start justify-between', className)} data-slot='plan-header' {...props} />
)

export type PlanTitleProps = Omit<ComponentProps<typeof CardTitle>, 'children'> & {
  children: string
}

export const PlanTitle = ({ children, ...props }: PlanTitleProps) => {
  const { isStreaming } = usePlan()

  return (
    <CardTitle data-slot='plan-title' {...props}>
      {isStreaming ? <Shimmer>{children}</Shimmer> : children}
    </CardTitle>
  )
}

export type PlanDescriptionProps = Omit<ComponentProps<typeof CardDescription>, 'children'> & {
  children: string
}

export const PlanDescription = ({ children, className, ...props }: PlanDescriptionProps) => {
  const { isStreaming } = usePlan()

  return (
    <CardDescription className={cn('text-balance', className)} data-slot='plan-description' {...props}>
      {isStreaming ? <Shimmer>{children}</Shimmer> : children}
    </CardDescription>
  )
}

export type PlanActionProps = ComponentProps<typeof CardAction>

export const PlanAction = (props: PlanActionProps) => <CardAction data-slot='plan-action' {...props} />

export type PlanContentProps = ComponentProps<typeof CardContent>

export const PlanContent = (props: PlanContentProps) => (
  <CollapsibleContent asChild>
    <CardContent data-slot='plan-content' {...props} />
  </CollapsibleContent>
)

export type PlanFooterProps = ComponentProps<'div'>

export const PlanFooter = (props: PlanFooterProps) => <CardFooter data-slot='plan-footer' {...props} />

export type PlanTriggerProps = ComponentProps<typeof CollapsibleTrigger>

export const PlanTrigger = ({ className, ...props }: PlanTriggerProps) => (
  <CollapsibleTrigger asChild>
    <Button className={cn('size-8', className)} data-slot='plan-trigger' size='icon' variant='ghost' {...props}>
      <ChevronsUpDownIcon className='size-4' />
      <span className='sr-only'>Toggle plan</span>
    </Button>
  </CollapsibleTrigger>
)

// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { DynamicToolUIPart, ToolUIPart } from 'ai'
import type { ComponentProps, ReactNode } from 'react'

import { cn } from '@a/ui'
import { Badge } from '@a/ui/badge'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@a/ui/collapsible'
import { CheckCircleIcon, ChevronDownIcon, CircleIcon, ClockIcon, WrenchIcon, XCircleIcon } from 'lucide-react'
import { isValidElement } from 'react'

import { CodeBlock } from './code-block'

export type ToolProps = ComponentProps<typeof Collapsible>

export const Tool = ({ className, ...props }: ToolProps) => (
  <Collapsible className={cn('group not-prose mb-4 w-full rounded-md border', className)} {...props} />
)

export type ToolHeaderProps = {
  className?: string
  title?: string
} & (
  | {
      state: DynamicToolUIPart['state']
      toolName: string
      type: DynamicToolUIPart['type']
    }
  | { state: ToolUIPart['state']; toolName?: never; type: ToolUIPart['type'] }
)

export type ToolPart = DynamicToolUIPart | ToolUIPart

export const getStatusBadge = (status: ToolPart['state']) => {
  const labels: Record<ToolPart['state'], string> = {
      'approval-requested': 'Awaiting Approval',
      'approval-responded': 'Responded',
      'input-available': 'Running',
      'input-streaming': 'Pending',
      'output-available': 'Completed',
      'output-denied': 'Denied',
      'output-error': 'Error'
    },
    icons: Record<ToolPart['state'], ReactNode> = {
      'approval-requested': <ClockIcon className='size-4 text-yellow-600' />,
      'approval-responded': <CheckCircleIcon className='size-4 text-blue-600' />,
      'input-available': <ClockIcon className='size-4 animate-pulse' />,
      'input-streaming': <CircleIcon className='size-4' />,
      'output-available': <CheckCircleIcon className='size-4 text-green-600' />,
      'output-denied': <XCircleIcon className='size-4 text-orange-600' />,
      'output-error': <XCircleIcon className='size-4 text-red-600' />
    }

  return (
    <Badge className='gap-1.5 rounded-full text-xs' variant='secondary'>
      {icons[status]}
      {labels[status]}
    </Badge>
  )
}

export const ToolHeader = ({ className, state, title, toolName, type, ...props }: ToolHeaderProps) => {
  const derivedName = type === 'dynamic-tool' ? toolName : type.split('-').slice(1).join('-')

  return (
    <CollapsibleTrigger className={cn('flex w-full items-center justify-between gap-4 p-3', className)} {...props}>
      <div className='flex items-center gap-2'>
        <WrenchIcon className='size-4 text-muted-foreground' />
        <span className='text-sm font-medium'>{title ?? derivedName}</span>
        {getStatusBadge(state)}
      </div>
      <ChevronDownIcon className='size-4 text-muted-foreground transition-transform group-data-[state=open]:rotate-180' />
    </CollapsibleTrigger>
  )
}

export type ToolContentProps = ComponentProps<typeof CollapsibleContent>

export const ToolContent = ({ className, ...props }: ToolContentProps) => (
  <CollapsibleContent
    className={cn(
      'text-popover-foreground outline-none data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:slide-out-to-top-2 data-[state=open]:animate-in data-[state=open]:slide-in-from-top-2',
      className
    )}
    {...props}
  />
)

export type ToolInputProps = ComponentProps<'div'> & {
  input: ToolPart['input']
}

export const ToolInput = ({ className, input, ...props }: ToolInputProps) => (
  <div className={cn('space-y-2 overflow-hidden p-4', className)} {...props}>
    <h4 className='text-xs font-medium tracking-wide text-muted-foreground uppercase'>Parameters</h4>
    <div className='rounded-md bg-muted/50'>
      <CodeBlock code={JSON.stringify(input, null, 2)} language='json' />
    </div>
  </div>
)

export type ToolOutputProps = ComponentProps<'div'> & {
  errorText: ToolPart['errorText']
  output: ToolPart['output']
}

export const ToolOutput = ({ className, errorText, output, ...props }: ToolOutputProps) => {
  if (!(output || errorText)) return null

  let Output = <div>{output as ReactNode}</div>

  if (typeof output === 'object' && !isValidElement(output))
    Output = <CodeBlock code={JSON.stringify(output, null, 2)} language='json' />
  else if (typeof output === 'string') Output = <CodeBlock code={output} language='json' />

  return (
    <div className={cn('space-y-2 p-4', className)} {...props}>
      <h4 className='text-xs font-medium tracking-wide text-muted-foreground uppercase'>
        {errorText ? 'Error' : 'Result'}
      </h4>
      <div
        className={cn(
          'overflow-x-auto rounded-md text-xs [&_table]:w-full',
          errorText ? 'bg-destructive/10 text-destructive' : 'bg-muted/50 text-foreground'
        )}>
        {errorText ? <div>{errorText}</div> : null}
        {Output}
      </div>
    </div>
  )
}

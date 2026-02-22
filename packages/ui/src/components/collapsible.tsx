'use client'

import { Collapsible as CollapsiblePrimitive } from 'radix-ui'

const Collapsible = ({ ...props }: React.ComponentProps<typeof CollapsiblePrimitive.Root>) => (
    <CollapsiblePrimitive.Root data-slot='collapsible' {...props} />
  ),
  CollapsibleTrigger = ({ ...props }: React.ComponentProps<typeof CollapsiblePrimitive.CollapsibleTrigger>) => (
    <CollapsiblePrimitive.CollapsibleTrigger data-slot='collapsible-trigger' {...props} />
  ),
  CollapsibleContent = ({ ...props }: React.ComponentProps<typeof CollapsiblePrimitive.CollapsibleContent>) => (
    <CollapsiblePrimitive.CollapsibleContent data-slot='collapsible-content' {...props} />
  )

export { Collapsible, CollapsibleContent, CollapsibleTrigger }

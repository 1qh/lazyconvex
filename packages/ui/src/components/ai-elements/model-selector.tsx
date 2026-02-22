// oxlint-disable import/exports-last, import/group-exports
import type { ComponentProps, ReactNode } from 'react'

import { cn } from '@a/ui'
import {
  Command,
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
  CommandShortcut
} from '@a/ui/command'
import { Dialog, DialogContent, DialogTitle, DialogTrigger } from '@a/ui/dialog'

export type ModelSelectorProps = ComponentProps<typeof Dialog>

export const ModelSelector = (props: ModelSelectorProps) => <Dialog {...props} />

export type ModelSelectorTriggerProps = ComponentProps<typeof DialogTrigger>

export const ModelSelectorTrigger = (props: ModelSelectorTriggerProps) => <DialogTrigger {...props} />

export type ModelSelectorContentProps = ComponentProps<typeof DialogContent> & {
  title?: ReactNode
}

export const ModelSelectorContent = ({
  children,
  className,
  title = 'Model Selector',
  ...props
}: ModelSelectorContentProps) => (
  <DialogContent className={cn('border-none! p-0 outline! outline-border! outline-solid!', className)} {...props}>
    <DialogTitle className='sr-only'>{title}</DialogTitle>
    <Command className='**:data-[slot=command-input-wrapper]:h-auto'>{children}</Command>
  </DialogContent>
)

export type ModelSelectorDialogProps = ComponentProps<typeof CommandDialog>

export const ModelSelectorDialog = (props: ModelSelectorDialogProps) => <CommandDialog {...props} />

export type ModelSelectorInputProps = ComponentProps<typeof CommandInput>

export const ModelSelectorInput = ({ className, ...props }: ModelSelectorInputProps) => (
  <CommandInput className={cn('h-auto py-3.5', className)} {...props} />
)

export type ModelSelectorListProps = ComponentProps<typeof CommandList>

export const ModelSelectorList = (props: ModelSelectorListProps) => <CommandList {...props} />

export type ModelSelectorEmptyProps = ComponentProps<typeof CommandEmpty>

export const ModelSelectorEmpty = (props: ModelSelectorEmptyProps) => <CommandEmpty {...props} />

export type ModelSelectorGroupProps = ComponentProps<typeof CommandGroup>

export const ModelSelectorGroup = (props: ModelSelectorGroupProps) => <CommandGroup {...props} />

export type ModelSelectorItemProps = ComponentProps<typeof CommandItem>

export const ModelSelectorItem = (props: ModelSelectorItemProps) => <CommandItem {...props} />

export type ModelSelectorShortcutProps = ComponentProps<typeof CommandShortcut>

export const ModelSelectorShortcut = (props: ModelSelectorShortcutProps) => <CommandShortcut {...props} />

export type ModelSelectorSeparatorProps = ComponentProps<typeof CommandSeparator>

export const ModelSelectorSeparator = (props: ModelSelectorSeparatorProps) => <CommandSeparator {...props} />

export type ModelSelectorLogoProps = Omit<ComponentProps<'img'>, 'alt' | 'src'> & {
  provider:
    | 'aihubmix'
    | 'alibaba'
    | 'alibaba-cn'
    | 'amazon-bedrock'
    | 'anthropic'
    | 'azure'
    | 'baseten'
    | 'cerebras'
    | 'chutes'
    | 'cloudflare-workers-ai'
    | 'cortecs'
    | 'deepinfra'
    | 'deepseek'
    | 'fastrouter'
    | 'fireworks-ai'
    | 'github-copilot'
    | 'github-models'
    | 'google'
    | 'google-vertex'
    | 'google-vertex-anthropic'
    | 'groq'
    | 'huggingface'
    | 'iflowcn'
    | 'inception'
    | 'inference'
    | 'llama'
    | 'lmstudio'
    | 'lucidquery'
    | 'mistral'
    | 'modelscope'
    | 'moonshotai'
    | 'moonshotai-cn'
    | 'morph'
    | 'nebius'
    | 'nvidia'
    | 'openai'
    | 'opencode'
    | 'openrouter'
    | 'perplexity'
    | 'requesty'
    | 'scaleway'
    | 'submodel'
    | 'synthetic'
    | 'togetherai'
    | 'upstage'
    | 'v0'
    | 'venice'
    | 'vercel'
    | 'vultr'
    | 'wandb'
    | 'xai'
    | 'zai'
    | 'zai-coding-plan'
    | 'zenmux'
    | 'zhipuai'
    | 'zhipuai-coding-plan'
    // oxlint-disable-next-line typescript/ban-types
    | (string & {})
}

export const ModelSelectorLogo = ({ className, provider, ...props }: ModelSelectorLogoProps) => (
  // eslint-disable-next-line @next/next/no-img-element
  <img
    {...props}
    alt={`${provider} logo`}
    className={cn('size-3 dark:invert', className)}
    height={12}
    src={`https://models.dev/logos/${provider}.svg`}
    width={12}
  />
)

export type ModelSelectorLogoGroupProps = ComponentProps<'div'>

export const ModelSelectorLogoGroup = ({ className, ...props }: ModelSelectorLogoGroupProps) => (
  <div
    className={cn(
      'flex shrink-0 items-center -space-x-1 [&>img]:rounded-full [&>img]:bg-background [&>img]:p-px [&>img]:ring-1 dark:[&>img]:bg-foreground',
      className
    )}
    {...props}
  />
)

export type ModelSelectorNameProps = ComponentProps<'span'>

export const ModelSelectorName = ({ className, ...props }: ModelSelectorNameProps) => (
  <span className={cn('flex-1 truncate text-left', className)} {...props} />
)

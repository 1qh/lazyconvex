/* eslint-disable complexity, @typescript-eslint/switch-exhaustiveness-check, no-useless-assignment, @typescript-eslint/no-redundant-type-constituents */
// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { ComponentProps, ReactNode } from 'react'

import { cn } from '@a/ui'
import { Button } from '@a/ui/button'
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
import { useControllableState } from '@radix-ui/react-use-controllable-state'
import {
  CircleSmallIcon,
  LoaderCircleIcon,
  MarsIcon,
  MarsStrokeIcon,
  NonBinaryIcon,
  PauseIcon,
  PlayIcon,
  TransgenderIcon,
  VenusAndMarsIcon,
  VenusIcon
} from 'lucide-react'
import { createContext, use, useMemo } from 'react'

interface VoiceSelectorContextValue {
  open: boolean
  setOpen: (open: boolean) => void
  setValue: (value: string | undefined) => void
  value: string | undefined
}

const VoiceSelectorContext = createContext<null | VoiceSelectorContextValue>(null)

export const useVoiceSelector = () => {
  const context = use(VoiceSelectorContext)
  if (!context) throw new Error('VoiceSelector components must be used within VoiceSelector')

  return context
}

export type VoiceSelectorProps = ComponentProps<typeof Dialog> & {
  defaultValue?: string
  onValueChange?: (value: string | undefined) => void
  value?: string
}

export const VoiceSelector = ({
  children,
  defaultOpen = false,
  defaultValue,
  // eslint-disable-next-line @typescript-eslint/unbound-method
  onOpenChange,
  onValueChange,
  open: openProp,
  value: valueProp,
  ...props
}: VoiceSelectorProps) => {
  const [value, setValue] = useControllableState({
      defaultProp: defaultValue,
      onChange: onValueChange,
      prop: valueProp
    }),
    [open, setOpen] = useControllableState({
      defaultProp: defaultOpen,
      onChange: onOpenChange,
      prop: openProp
    }),
    voiceSelectorContext = useMemo(() => ({ open, setOpen, setValue, value }), [value, setValue, open, setOpen])

  return (
    <VoiceSelectorContext value={voiceSelectorContext}>
      <Dialog onOpenChange={setOpen} open={open} {...props}>
        {children}
      </Dialog>
    </VoiceSelectorContext>
  )
}

export type VoiceSelectorTriggerProps = ComponentProps<typeof DialogTrigger>

export const VoiceSelectorTrigger = (props: VoiceSelectorTriggerProps) => <DialogTrigger {...props} />

export type VoiceSelectorContentProps = ComponentProps<typeof DialogContent> & {
  title?: ReactNode
}

export const VoiceSelectorContent = ({
  children,
  className,
  title = 'Voice Selector',
  ...props
}: VoiceSelectorContentProps) => (
  <DialogContent className={cn('p-0', className)} {...props}>
    <DialogTitle className='sr-only'>{title}</DialogTitle>
    <Command className='**:data-[slot=command-input-wrapper]:h-auto'>{children}</Command>
  </DialogContent>
)

export type VoiceSelectorDialogProps = ComponentProps<typeof CommandDialog>

export const VoiceSelectorDialog = (props: VoiceSelectorDialogProps) => <CommandDialog {...props} />

export type VoiceSelectorInputProps = ComponentProps<typeof CommandInput>

export const VoiceSelectorInput = ({ className, ...props }: VoiceSelectorInputProps) => (
  <CommandInput className={cn('h-auto py-3.5', className)} {...props} />
)

export type VoiceSelectorListProps = ComponentProps<typeof CommandList>

export const VoiceSelectorList = (props: VoiceSelectorListProps) => <CommandList {...props} />

export type VoiceSelectorEmptyProps = ComponentProps<typeof CommandEmpty>

export const VoiceSelectorEmpty = (props: VoiceSelectorEmptyProps) => <CommandEmpty {...props} />

export type VoiceSelectorGroupProps = ComponentProps<typeof CommandGroup>

export const VoiceSelectorGroup = (props: VoiceSelectorGroupProps) => <CommandGroup {...props} />

export type VoiceSelectorItemProps = ComponentProps<typeof CommandItem>

export const VoiceSelectorItem = ({ className, ...props }: VoiceSelectorItemProps) => (
  <CommandItem className={cn('px-4 py-2', className)} {...props} />
)

export type VoiceSelectorShortcutProps = ComponentProps<typeof CommandShortcut>

export const VoiceSelectorShortcut = (props: VoiceSelectorShortcutProps) => <CommandShortcut {...props} />

export type VoiceSelectorSeparatorProps = ComponentProps<typeof CommandSeparator>

export const VoiceSelectorSeparator = (props: VoiceSelectorSeparatorProps) => <CommandSeparator {...props} />

export type VoiceSelectorGenderProps = ComponentProps<'span'> & {
  value?: 'androgyne' | 'female' | 'intersex' | 'male' | 'non-binary' | 'transgender'
}

export const VoiceSelectorGender = ({ children, className, value, ...props }: VoiceSelectorGenderProps) => {
  let icon: null | ReactNode = null

  switch (value) {
    case 'androgyne':
      icon = <MarsStrokeIcon className='size-4' />
      break
    case 'female':
      icon = <VenusIcon className='size-4' />
      break
    case 'intersex':
      icon = <VenusAndMarsIcon className='size-4' />
      break
    case 'male':
      icon = <MarsIcon className='size-4' />
      break
    case 'non-binary':
      icon = <NonBinaryIcon className='size-4' />
      break
    case 'transgender':
      icon = <TransgenderIcon className='size-4' />
      break
    default:
      icon = <CircleSmallIcon className='size-4' />
  }

  return (
    <span className={cn('text-xs text-muted-foreground', className)} {...props}>
      {children ?? icon}
    </span>
  )
}

export type VoiceSelectorAccentProps = ComponentProps<'span'> & {
  value?:
    | 'american'
    | 'arabic'
    | 'argentinian'
    | 'australian'
    | 'brazilian'
    | 'british'
    | 'canadian'
    | 'chinese'
    | 'danish'
    | 'dutch'
    | 'finnish'
    | 'french'
    | 'german'
    | 'greek'
    | 'indian'
    | 'irish'
    | 'italian'
    | 'japanese'
    | 'korean'
    | 'mexican'
    | 'new-zealand'
    | 'norwegian'
    | 'polish'
    | 'portuguese'
    | 'russian'
    | 'scottish'
    | 'south-african'
    | 'spanish'
    | 'swedish'
    | 'turkish'
    | string
}

export const VoiceSelectorAccent = ({ children, className, value, ...props }: VoiceSelectorAccentProps) => {
  let emoji: null | string = null

  switch (value) {
    case 'american':
      emoji = '🇺🇸'
      break
    case 'arabic':
      emoji = '🇸🇦'
      break
    case 'argentinian':
      emoji = '🇦🇷'
      break
    case 'australian':
      emoji = '🇦🇺'
      break
    case 'brazilian':
      emoji = '🇧🇷'
      break
    case 'british':
      emoji = '🇬🇧'
      break
    case 'canadian':
      emoji = '🇨🇦'
      break
    case 'chinese':
      emoji = '🇨🇳'
      break
    case 'danish':
      emoji = '🇩🇰'
      break
    case 'dutch':
      emoji = '🇳🇱'
      break
    case 'finnish':
      emoji = '🇫🇮'
      break
    case 'french':
      emoji = '🇫🇷'
      break
    case 'german':
      emoji = '🇩🇪'
      break
    case 'greek':
      emoji = '🇬🇷'
      break
    case 'indian':
      emoji = '🇮🇳'
      break
    case 'irish':
      emoji = '🇮🇪'
      break
    case 'italian':
      emoji = '🇮🇹'
      break
    case 'japanese':
      emoji = '🇯🇵'
      break
    case 'korean':
      emoji = '🇰🇷'
      break
    case 'mexican':
      emoji = '🇲🇽'
      break
    case 'new-zealand':
      emoji = '🇳🇿'
      break
    case 'norwegian':
      emoji = '🇳🇴'
      break
    case 'polish':
      emoji = '🇵🇱'
      break
    case 'portuguese':
      emoji = '🇵🇹'
      break
    case 'russian':
      emoji = '🇷🇺'
      break
    case 'scottish':
      emoji = '🏴󠁧󠁢󠁳󠁣󠁴󠁿'
      break
    case 'south-african':
      emoji = '🇿🇦'
      break
    case 'spanish':
      emoji = '🇪🇸'
      break
    case 'swedish':
      emoji = '🇸🇪'
      break
    case 'turkish':
      emoji = '🇹🇷'
      break
    default:
      emoji = null
  }

  return (
    <span className={cn('text-xs text-muted-foreground', className)} {...props}>
      {children ?? emoji}
    </span>
  )
}

export type VoiceSelectorAgeProps = ComponentProps<'span'>

export const VoiceSelectorAge = ({ className, ...props }: VoiceSelectorAgeProps) => (
  <span className={cn('text-xs text-muted-foreground tabular-nums', className)} {...props} />
)

export type VoiceSelectorNameProps = ComponentProps<'span'>

export const VoiceSelectorName = ({ className, ...props }: VoiceSelectorNameProps) => (
  <span className={cn('flex-1 truncate text-left font-medium', className)} {...props} />
)

export type VoiceSelectorDescriptionProps = ComponentProps<'span'>

export const VoiceSelectorDescription = ({ className, ...props }: VoiceSelectorDescriptionProps) => (
  <span className={cn('text-xs text-muted-foreground', className)} {...props} />
)

export type VoiceSelectorAttributesProps = ComponentProps<'div'>

export const VoiceSelectorAttributes = ({ children, className, ...props }: VoiceSelectorAttributesProps) => (
  <div className={cn('flex items-center text-xs', className)} {...props}>
    {children}
  </div>
)

export type VoiceSelectorBulletProps = ComponentProps<'span'>

export const VoiceSelectorBullet = ({ className, ...props }: VoiceSelectorBulletProps) => (
  <span aria-hidden='true' className={cn('text-border select-none', className)} {...props}>
    &bull;
  </span>
)

export type VoiceSelectorPreviewProps = Omit<ComponentProps<'button'>, 'children'> & {
  loading?: boolean
  onPlay?: () => void
  playing?: boolean
}

export const VoiceSelectorPreview = ({
  className,
  loading,
  onClick,
  onPlay,
  playing,
  ...props
}: VoiceSelectorPreviewProps) => {
  const handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {
    event.stopPropagation()
    onClick?.(event)
    onPlay?.()
  }

  let icon = <PlayIcon className='size-3' />

  if (loading) icon = <LoaderCircleIcon className='size-3 animate-spin' />
  else if (playing) icon = <PauseIcon className='size-3' />

  return (
    <Button
      aria-label={playing ? 'Pause preview' : 'Play preview'}
      className={cn('size-6', className)}
      disabled={loading}
      onClick={handleClick}
      size='icon-sm'
      type='button'
      variant='outline'
      {...props}>
      {icon}
    </Button>
  )
}

/* eslint-disable prefer-named-capture-group */
/* eslint-disable max-statements */
// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { ComponentProps, ReactNode } from 'react'

import { cn } from '@a/ui'
import { Button } from '@a/ui/button'
import { Command, CommandEmpty, CommandInput, CommandItem, CommandList } from '@a/ui/command'
import { Popover, PopoverContent, PopoverTrigger } from '@a/ui/popover'
import { useControllableState } from '@radix-ui/react-use-controllable-state'
import { ChevronsUpDownIcon } from 'lucide-react'
import { createContext, use, useCallback, useEffect, useRef, useState } from 'react'

const deviceIdRegex = /\(([\da-fA-F]{4}:[\da-fA-F]{4})\)$/u

interface MicSelectorContextType {
  data: MediaDeviceInfo[]
  onOpenChange?: (open: boolean) => void
  onValueChange?: (value: string) => void
  open: boolean
  setWidth?: (width: number) => void
  value: string | undefined
  width: number
}

const MicSelectorContext = createContext<MicSelectorContextType>({
  data: [],
  onOpenChange: undefined,
  onValueChange: undefined,
  open: false,
  setWidth: undefined,
  value: undefined,
  width: 200
})

export type MicSelectorTriggerProps = ComponentProps<typeof Button>

export const MicSelectorTrigger = ({ children, ...props }: MicSelectorTriggerProps) => {
  const { setWidth } = use(MicSelectorContext),
    ref = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    // Create a ResizeObserver to detect width changes
    const resizeObserver = new ResizeObserver(entries => {
      for (const entry of entries) {
        const newWidth = (entry.target as HTMLElement).offsetWidth
        if (newWidth) setWidth?.(newWidth)
      }
    })

    if (ref.current) resizeObserver.observe(ref.current)

    // Clean up the observer when component unmounts
    return () => {
      resizeObserver.disconnect()
    }
  }, [setWidth])

  return (
    <PopoverTrigger asChild>
      <Button variant='outline' {...props} ref={ref}>
        {children}
        <ChevronsUpDownIcon className='shrink-0 text-muted-foreground' size={16} />
      </Button>
    </PopoverTrigger>
  )
}

export type MicSelectorContentProps = ComponentProps<typeof Command> & {
  popoverOptions?: ComponentProps<typeof PopoverContent>
}

export const MicSelectorContent = ({ className, popoverOptions, ...props }: MicSelectorContentProps) => {
  const { onValueChange, value, width } = use(MicSelectorContext)

  return (
    <PopoverContent className={cn('p-0', className)} style={{ width }} {...popoverOptions}>
      <Command onValueChange={onValueChange} value={value} {...props} />
    </PopoverContent>
  )
}

export type MicSelectorInputProps = ComponentProps<typeof CommandInput> & {
  defaultValue?: string
  onValueChange?: (value: string) => void
  value?: string
}

export const MicSelectorInput = ({ ...props }: MicSelectorInputProps) => (
  <CommandInput placeholder='Search microphones...' {...props} />
)

export type MicSelectorListProps = Omit<ComponentProps<typeof CommandList>, 'children'> & {
  children: (devices: MediaDeviceInfo[]) => ReactNode
}

export const MicSelectorList = ({ children, ...props }: MicSelectorListProps) => {
  const { data } = use(MicSelectorContext)

  return <CommandList {...props}>{children(data)}</CommandList>
}

export type MicSelectorEmptyProps = ComponentProps<typeof CommandEmpty>

export const MicSelectorEmpty = ({ children = 'No microphone found.', ...props }: MicSelectorEmptyProps) => (
  <CommandEmpty {...props}>{children}</CommandEmpty>
)

export type MicSelectorItemProps = ComponentProps<typeof CommandItem>

export const MicSelectorItem = (props: MicSelectorItemProps) => {
  const { onOpenChange, onValueChange } = use(MicSelectorContext)

  return (
    <CommandItem
      onSelect={currentValue => {
        onValueChange?.(currentValue)
        onOpenChange?.(false)
      }}
      {...props}
    />
  )
}

export type MicSelectorLabelProps = ComponentProps<'span'> & {
  device: MediaDeviceInfo
}

export const MicSelectorLabel = ({ className, device, ...props }: MicSelectorLabelProps) => {
  const matches = deviceIdRegex.exec(device.label)

  console.log(matches, device.label)

  if (!matches)
    return (
      <span className={className} {...props}>
        {device.label}
      </span>
    )

  const [, deviceId] = matches,
    name = device.label.replace(deviceIdRegex, '')

  return (
    <span className={className} {...props}>
      <span>{name}</span>
      <span className='text-muted-foreground'> ({deviceId})</span>
    </span>
  )
}

export type MicSelectorValueProps = ComponentProps<'span'>

export const MicSelectorValue = ({ className, ...props }: MicSelectorValueProps) => {
  const { data, value } = use(MicSelectorContext),
    currentDevice = data.find(d => d.deviceId === value)

  if (!currentDevice)
    return (
      <span className={cn('flex-1 text-left', className)} {...props}>
        Select microphone...
      </span>
    )

  return <MicSelectorLabel className={cn('flex-1 text-left', className)} device={currentDevice} {...props} />
}

export const useAudioDevices = () => {
  const [devices, setDevices] = useState<MediaDeviceInfo[]>([]),
    [loading, setLoading] = useState(true),
    [er, setEr] = useState<null | string>(null),
    [hasPermission, setHasPermission] = useState(false),
    loadDevicesWithoutPermission = useCallback(async () => {
      try {
        setLoading(true)
        setEr(null)

        const deviceList = await navigator.mediaDevices.enumerateDevices(),
          audioInputs = deviceList.filter(device => device.kind === 'audioinput')

        setDevices(audioInputs)
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to get audio devices'

        setEr(message)
        console.error('Error getting audio devices:', message)
      } finally {
        setLoading(false)
      }
    }, []),
    loadDevicesWithPermission = useCallback(async () => {
      if (loading) return

      try {
        setLoading(true)
        setEr(null)

        const tempStream = await navigator.mediaDevices.getUserMedia({
          audio: true
        })

        for (const track of tempStream.getTracks()) track.stop()

        const deviceList = await navigator.mediaDevices.enumerateDevices(),
          audioInputs = deviceList.filter(device => device.kind === 'audioinput')

        setDevices(audioInputs)
        setHasPermission(true)
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to get audio devices'

        setEr(message)
        console.error('Error getting audio devices:', message)
      } finally {
        setLoading(false)
      }
    }, [loading])

  useEffect(() => {
    loadDevicesWithoutPermission()
  }, [loadDevicesWithoutPermission])

  useEffect(() => {
    const handleDeviceChange = () => {
      if (hasPermission) loadDevicesWithPermission()
      else loadDevicesWithoutPermission()
    }

    navigator.mediaDevices.addEventListener('devicechange', handleDeviceChange)

    return () => {
      navigator.mediaDevices.removeEventListener('devicechange', handleDeviceChange)
    }
  }, [hasPermission, loadDevicesWithPermission, loadDevicesWithoutPermission])

  return {
    devices,
    error: er,
    hasPermission,
    loadDevices: loadDevicesWithPermission,
    loading
  }
}

export type MicSelectorProps = ComponentProps<typeof Popover> & {
  defaultValue?: string
  onOpenChange?: (open: boolean) => void
  onValueChange?: (value: string | undefined) => void
  open?: boolean
  value?: string | undefined
}

export const MicSelector = ({
  defaultOpen = false,
  defaultValue,
  onOpenChange: controlledOnOpenChange,
  onValueChange: controlledOnValueChange,
  open: controlledOpen,
  value: controlledValue,
  ...props
}: MicSelectorProps) => {
  const [value, onValueChange] = useControllableState<string | undefined>({
      defaultProp: defaultValue,
      onChange: controlledOnValueChange,
      prop: controlledValue
    }),
    [open, onOpenChange] = useControllableState({
      defaultProp: defaultOpen,
      onChange: controlledOnOpenChange,
      prop: controlledOpen
    }),
    [width, setWidth] = useState(200),
    { devices, hasPermission, loadDevices, loading } = useAudioDevices()

  useEffect(() => {
    if (open && !hasPermission && !loading) loadDevices()
  }, [open, hasPermission, loading, loadDevices])

  return (
    <MicSelectorContext
      value={{
        data: devices,
        onOpenChange,
        onValueChange,
        open,
        setWidth,
        value,
        width
      }}>
      <Popover {...props} onOpenChange={onOpenChange} open={open} />
    </MicSelectorContext>
  )
}

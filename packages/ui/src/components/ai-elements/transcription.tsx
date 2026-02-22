// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { Experimental_TranscriptionResult as TranscriptionResult } from 'ai'
import type { ComponentProps, ReactNode } from 'react'

import { cn } from '@a/ui'
import { useControllableState } from '@radix-ui/react-use-controllable-state'
import { createContext, use } from 'react'

interface TranscriptionContextValue {
  currentTime: number
  onSeek?: (time: number) => void
  onTimeUpdate: (time: number) => void
  segments: TranscriptionSegment[]
}

type TranscriptionSegment = TranscriptionResult['segments'][number]

const TranscriptionContext = createContext<null | TranscriptionContextValue>(null),
  useTranscription = () => {
    const context = use(TranscriptionContext)
    if (!context) throw new Error('Transcription components must be used within Transcription')

    return context
  }

export type TranscriptionProps = Omit<ComponentProps<'div'>, 'children'> & {
  children: (segment: TranscriptionSegment, index: number) => ReactNode
  currentTime?: number
  onSeek?: (time: number) => void
  segments: TranscriptionSegment[]
}

export const Transcription = ({
  children,
  className,
  currentTime: externalCurrentTime,
  onSeek,
  segments,
  ...props
}: TranscriptionProps) => {
  const [currentTime, setCurrentTime] = useControllableState({
    defaultProp: 0,
    onChange: onSeek,
    prop: externalCurrentTime
  })

  return (
    <TranscriptionContext
      value={{
        currentTime,
        onSeek,
        onTimeUpdate: setCurrentTime,
        segments
      }}>
      <div className={cn('flex flex-wrap gap-1 text-sm/relaxed', className)} data-slot='transcription' {...props}>
        {segments.filter(segment => segment.text.trim()).map(async (segment, index) => children(segment, index))}
      </div>
    </TranscriptionContext>
  )
}

export type TranscriptionSegmentProps = ComponentProps<'button'> & {
  index: number
  segment: TranscriptionSegment
}

// eslint-disable-next-line @typescript-eslint/no-redeclare
export const TranscriptionSegment = ({ className, index, onClick, segment, ...props }: TranscriptionSegmentProps) => {
  const { currentTime, onSeek } = useTranscription(),
    isActive = currentTime >= segment.startSecond && currentTime < segment.endSecond,
    isPast = currentTime >= segment.endSecond,
    handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {
      if (onSeek) onSeek(segment.startSecond)

      onClick?.(event)
    }

  return (
    <button
      className={cn(
        'inline text-left',
        isActive && 'text-primary',
        isPast && 'text-muted-foreground',
        !(isActive || isPast) && 'text-muted-foreground/60',
        onSeek && 'cursor-pointer hover:text-foreground',
        !onSeek && 'cursor-default',
        className
      )}
      data-active={isActive}
      data-index={index}
      data-slot='transcription-segment'
      onClick={handleClick}
      type='button'
      {...props}>
      {segment.text}
    </button>
  )
}

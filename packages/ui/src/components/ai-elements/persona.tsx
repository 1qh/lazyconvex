/* eslint-disable react-hooks/immutability */
/* eslint-disable react/display-name */
// oxlint-disable import/exports-last, import/group-exports
/* eslint-disable @typescript-eslint/promise-function-async */
'use client'

import type { RiveParameters } from '@rive-app/react-webgl2'
import type { FC, ReactNode } from 'react'

import { cn } from '@a/ui'
import {
  useRive,
  useStateMachineInput,
  useViewModel,
  useViewModelInstance,
  useViewModelInstanceColor
} from '@rive-app/react-webgl2'
import { memo, useEffect, useMemo, useRef, useState } from 'react'

export type PersonaState = 'asleep' | 'idle' | 'listening' | 'speaking' | 'thinking'

interface PersonaProps {
  className?: string
  onLoad?: RiveParameters['onLoad']
  onLoadError?: RiveParameters['onLoadError']
  onPause?: RiveParameters['onPause']
  onPlay?: RiveParameters['onPlay']
  onReady?: () => void
  onStop?: RiveParameters['onStop']
  state: PersonaState
  variant?: keyof typeof sources
}

// The state machine name is always 'default' for Elements AI visuals
const stateMachine = 'default',
  sources = {
    command: {
      dynamicColor: true,
      hasModel: true,
      source: 'https://ejiidnob33g9ap1r.public.blob.vercel-storage.com/command-2.0.riv'
    },
    glint: {
      dynamicColor: true,
      hasModel: true,
      source: 'https://ejiidnob33g9ap1r.public.blob.vercel-storage.com/glint-2.0.riv'
    },
    halo: {
      dynamicColor: true,
      hasModel: true,
      source: 'https://ejiidnob33g9ap1r.public.blob.vercel-storage.com/halo-2.0.riv'
    },
    mana: {
      dynamicColor: false,
      hasModel: true,
      source: 'https://ejiidnob33g9ap1r.public.blob.vercel-storage.com/mana-2.0.riv'
    },
    obsidian: {
      dynamicColor: true,
      hasModel: true,
      source: 'https://ejiidnob33g9ap1r.public.blob.vercel-storage.com/obsidian-2.0.riv'
    },
    opal: {
      dynamicColor: false,
      hasModel: false,
      source: 'https://ejiidnob33g9ap1r.public.blob.vercel-storage.com/orb-1.2.riv'
    }
  },
  getCurrentTheme = (): 'dark' | 'light' => {
    if (typeof window !== 'undefined') {
      if (document.documentElement.classList.contains('dark')) return 'dark'

      if (globalThis.matchMedia('(prefers-color-scheme: dark)').matches) return 'dark'
    }
    return 'light'
  },
  useTheme = (enabled: boolean) => {
    const [theme, setTheme] = useState<'dark' | 'light'>(getCurrentTheme)

    useEffect(() => {
      // Skip if not enabled (avoids unnecessary observers for non-dynamic-color variants)
      if (!enabled) return

      // Watch for classList changes
      const observer = new MutationObserver(() => {
        setTheme(getCurrentTheme())
      })

      observer.observe(document.documentElement, {
        attributeFilter: ['class'],
        attributes: true
      })

      // Watch for OS-level theme changes
      let mql: MediaQueryList | null = null
      const handleMediaChange = () => {
        setTheme(getCurrentTheme())
      }

      // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
      if (globalThis.matchMedia) {
        mql = globalThis.matchMedia('(prefers-color-scheme: dark)')
        mql.addEventListener('change', handleMediaChange)
      }

      return () => {
        observer.disconnect()
        if (mql) mql.removeEventListener('change', handleMediaChange)
      }
    }, [enabled])

    return theme
  }

interface PersonaWithModelProps {
  children: React.ReactNode
  rive: ReturnType<typeof useRive>['rive']
  source: (typeof sources)[keyof typeof sources]
}

const PersonaWithModel = memo(({ children, rive, source }: PersonaWithModelProps) => {
  const theme = useTheme(source.dynamicColor),
    viewModel = useViewModel(rive, { useDefault: true }),
    viewModelInstance = useViewModelInstance(viewModel, {
      rive,
      useDefault: true
    }),
    viewModelInstanceColor = useViewModelInstanceColor('color', viewModelInstance)

  useEffect(() => {
    if (!(viewModelInstanceColor.value && source.dynamicColor)) return

    const [r, g, b] = theme === 'dark' ? [255, 255, 255] : [0, 0, 0]
    viewModelInstanceColor.setRgb(r, g, b)
  }, [viewModelInstanceColor, theme, source.dynamicColor])

  return children
})

interface PersonaWithoutModelProps {
  children: ReactNode
}

const PersonaWithoutModel = memo(({ children }: PersonaWithoutModelProps) => children)

export const Persona: FC<PersonaProps> = memo(
  ({ className, onLoad, onLoadError, onPause, onPlay, onReady, onStop, state, variant = 'obsidian' }) => {
    const source = sources[variant]

    if (!source.source) throw new Error(`Invalid variant: ${variant}`)

    // Stabilize callbacks to prevent useRive from reinitializing
    const callbacksRef = useRef({
      onLoad,
      onLoadError,
      onPause,
      onPlay,
      onReady,
      onStop
    })
    callbacksRef.current = {
      onLoad,
      onLoadError,
      onPause,
      onPlay,
      onReady,
      onStop
    }

    const stableCallbacks = useMemo(
        () => ({
          onLoad: (loadedRive => callbacksRef.current.onLoad?.(loadedRive)) as RiveParameters['onLoad'],
          onLoadError: (err => callbacksRef.current.onLoadError?.(err)) as RiveParameters['onLoadError'],
          onPause: (event => callbacksRef.current.onPause?.(event)) as RiveParameters['onPause'],
          onPlay: (event => callbacksRef.current.onPlay?.(event)) as RiveParameters['onPlay'],
          onReady: () => callbacksRef.current.onReady?.(),
          onStop: (event => callbacksRef.current.onStop?.(event)) as RiveParameters['onStop']
        }),
        []
      ),
      { rive, RiveComponent } = useRive({
        autoplay: true,
        onLoad: stableCallbacks.onLoad,
        onLoadError: stableCallbacks.onLoadError,
        onPause: stableCallbacks.onPause,
        onPlay: stableCallbacks.onPlay,
        onRiveReady: stableCallbacks.onReady,
        onStop: stableCallbacks.onStop,
        src: source.source,
        stateMachines: stateMachine
      }),
      listeningInput = useStateMachineInput(rive, stateMachine, 'listening'),
      thinkingInput = useStateMachineInput(rive, stateMachine, 'thinking'),
      speakingInput = useStateMachineInput(rive, stateMachine, 'speaking'),
      asleepInput = useStateMachineInput(rive, stateMachine, 'asleep')

    useEffect(() => {
      if (listeningInput) listeningInput.value = state === 'listening'

      if (thinkingInput) thinkingInput.value = state === 'thinking'

      if (speakingInput) speakingInput.value = state === 'speaking'

      if (asleepInput) asleepInput.value = state === 'asleep'
    }, [state, listeningInput, thinkingInput, speakingInput, asleepInput])

    const Component = source.hasModel ? PersonaWithModel : PersonaWithoutModel

    return (
      <Component rive={rive} source={source}>
        <RiveComponent className={cn('size-16 shrink-0', className)} />
      </Component>
    )
  }
)

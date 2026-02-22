// oxlint-disable unicorn/prefer-add-event-listener
/* eslint-disable max-statements */
// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { ComponentProps } from 'react'

import { cn } from '@a/ui'
import { Button } from '@a/ui/button'
import { LoaderIcon, MicIcon, SquareIcon } from 'lucide-react'
import { useCallback, useEffect, useRef, useState } from 'react'

interface SpeechRecognition extends EventTarget {
  continuous: boolean
  interimResults: boolean
  lang: string
  onend: ((this: SpeechRecognition, ev: Event) => void) | null
  onerror: ((this: SpeechRecognition, ev: SpeechRecognitionErrorEvent) => void) | null
  onresult: ((this: SpeechRecognition, ev: SpeechRecognitionEvent) => void) | null
  onstart: ((this: SpeechRecognition, ev: Event) => void) | null
  start: () => void
  stop: () => void
}

interface SpeechRecognitionAlternative {
  confidence: number
  transcript: string
}

interface SpeechRecognitionErrorEvent extends Event {
  error: string
}

interface SpeechRecognitionEvent extends Event {
  resultIndex: number
  results: SpeechRecognitionResultList
}

interface SpeechRecognitionResult {
  [index: number]: SpeechRecognitionAlternative
  isFinal: boolean
  item: (index: number) => SpeechRecognitionAlternative
  readonly length: number
}

interface SpeechRecognitionResultList {
  [index: number]: SpeechRecognitionResult
  item: (index: number) => SpeechRecognitionResult
  readonly length: number
}

declare global {
  interface Window {
    SpeechRecognition: new () => SpeechRecognition
    webkitSpeechRecognition: new () => SpeechRecognition
  }
}

export type SpeechInputProps = ComponentProps<typeof Button> & {
  lang?: string
  /**
   * Callback for when audio is recorded using MediaRecorder fallback.
   * This is called in browsers that don't support the Web Speech API (Firefox, Safari).
   * The callback receives an audio Blob that should be sent to a transcription service.
   * Return the transcribed text, which will be passed to onTranscriptionChange.
   */
  onAudioRecorded?: (audioBlob: Blob) => Promise<string>
  onTranscriptionChange?: (text: string) => void
}

type SpeechInputMode = 'media-recorder' | 'none' | 'speech-recognition'

const detectSpeechInputMode = (): SpeechInputMode => {
  if (typeof window === 'undefined') return 'none'

  if ('SpeechRecognition' in globalThis || 'webkitSpeechRecognition' in globalThis) return 'speech-recognition'

  if ('MediaRecorder' in globalThis && 'mediaDevices' in navigator) return 'media-recorder'

  return 'none'
}

export const SpeechInput = ({
  className,
  lang = 'en-US',
  onAudioRecorded,
  onTranscriptionChange,
  ...props
}: SpeechInputProps) => {
  const [isListening, setIsListening] = useState(false),
    [isProcessing, setIsProcessing] = useState(false),
    [mode, setMode] = useState<SpeechInputMode>('none'),
    [recognition, setRecognition] = useState<null | SpeechRecognition>(null),
    recognitionRef = useRef<null | SpeechRecognition>(null),
    mediaRecorderRef = useRef<MediaRecorder | null>(null),
    audioChunksRef = useRef<Blob[]>([])

  // Detect mode on mount
  useEffect(() => {
    setMode(detectSpeechInputMode())
  }, [])

  // Initialize Speech Recognition when mode is speech-recognition
  useEffect(() => {
    if (mode !== 'speech-recognition') return

    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
    const SpeechRecog = window.SpeechRecognition || window.webkitSpeechRecognition,
      speechRecognition = new SpeechRecog()

    speechRecognition.continuous = true
    speechRecognition.interimResults = true
    speechRecognition.lang = lang

    speechRecognition.onstart = () => {
      setIsListening(true)
    }

    speechRecognition.onend = () => {
      setIsListening(false)
    }

    speechRecognition.onresult = (event: SpeechRecognitionEvent) => {
      let finalTranscript = ''

      for (let i = event.resultIndex; i < event.results.length; i += 1) {
        const result = event.results[i]
        if (result?.isFinal) finalTranscript += result[0]?.transcript ?? ''
      }

      if (finalTranscript) onTranscriptionChange?.(finalTranscript)
    }

    speechRecognition.onerror = event => {
      console.error('Speech recognition error:', event.error)
      setIsListening(false)
    }

    recognitionRef.current = speechRecognition
    setRecognition(speechRecognition)

    return () => {
      if (recognitionRef.current) recognitionRef.current.stop()
    }
  }, [mode, onTranscriptionChange, lang])

  // Start MediaRecorder recording
  const startMediaRecorder = useCallback(async () => {
      if (!onAudioRecorded) {
        console.warn('SpeechInput: onAudioRecorded callback is required for MediaRecorder fallback')
        return
      }

      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true }),
          mediaRecorder = new MediaRecorder(stream)
        audioChunksRef.current = []

        mediaRecorder.ondataavailable = event => {
          if (event.data.size > 0) audioChunksRef.current.push(event.data)
        }

        mediaRecorder.onstop = async () => {
          // Stop all tracks to release the microphone
          for (const track of stream.getTracks()) track.stop()

          const audioBlob = new Blob(audioChunksRef.current, {
            type: 'audio/webm'
          })

          if (audioBlob.size > 0) {
            setIsProcessing(true)
            try {
              const transcript = await onAudioRecorded(audioBlob)
              if (transcript) onTranscriptionChange?.(transcript)
            } catch (error) {
              console.error('Transcription error:', error)
            } finally {
              setIsProcessing(false)
            }
          }
        }

        mediaRecorder.onerror = event => {
          console.error('MediaRecorder error:', event)
          setIsListening(false)
          // Stop all tracks on error
          for (const track of stream.getTracks()) track.stop()
        }

        mediaRecorderRef.current = mediaRecorder
        mediaRecorder.start()
        setIsListening(true)
      } catch (error) {
        console.error('Failed to start MediaRecorder:', error)
        setIsListening(false)
      }
    }, [onAudioRecorded, onTranscriptionChange]),
    // Stop MediaRecorder recording
    stopMediaRecorder = useCallback(() => {
      if (mediaRecorderRef.current?.state === 'recording') mediaRecorderRef.current.stop()

      setIsListening(false)
    }, []),
    toggleListening = useCallback(() => {
      if (mode === 'speech-recognition' && recognition)
        if (isListening) recognition.stop()
        else recognition.start()
      else if (mode === 'media-recorder')
        if (isListening) stopMediaRecorder()
        else startMediaRecorder()
    }, [mode, recognition, isListening, startMediaRecorder, stopMediaRecorder]),
    // Determine if button should be disabled
    isDisabled =
      mode === 'none' ||
      (mode === 'speech-recognition' && !recognition) ||
      (mode === 'media-recorder' && !onAudioRecorded) ||
      isProcessing

  return (
    <div className='relative inline-flex items-center justify-center'>
      {/* Animated pulse rings */}
      {isListening
        ? [0, 1, 2].map(index => (
            <div
              className='absolute inset-0 animate-ping rounded-full border-2 border-red-400/30'
              key={index}
              style={{
                animationDelay: `${index * 0.3}s`,
                animationDuration: '2s'
              }}
            />
          ))
        : null}

      {/* Main record button */}
      <Button
        className={cn(
          'relative z-10 rounded-full transition-all duration-300',
          isListening
            ? 'bg-destructive text-white hover:bg-destructive/80 hover:text-white'
            : 'bg-primary text-primary-foreground hover:bg-primary/80 hover:text-primary-foreground',
          className
        )}
        disabled={isDisabled}
        onClick={toggleListening}
        {...props}>
        {isProcessing ? <LoaderIcon className='size-4 animate-spin' /> : null}
        {!isProcessing && isListening ? <SquareIcon className='size-4' /> : null}
        {!(isProcessing || isListening) && <MicIcon className='size-4' />}
      </Button>
    </div>
  )
}

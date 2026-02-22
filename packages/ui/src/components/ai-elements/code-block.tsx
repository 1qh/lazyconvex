/* eslint-disable no-bitwise */
// oxlint-disable promise/always-return, promise/prefer-await-to-then, promise/prefer-await-to-callbacks
// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { ComponentProps, CSSProperties, HTMLAttributes } from 'react'
import type { BundledLanguage, BundledTheme, HighlighterGeneric, ThemedToken } from 'shiki'

import { cn } from '@a/ui'
import { Button } from '@a/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@a/ui/select'
import { CheckIcon, CopyIcon } from 'lucide-react'
import { createContext, memo, use, useEffect, useMemo, useRef, useState } from 'react'
import { createHighlighter } from 'shiki'

// Shiki uses bitflags for font styles: 1=italic, 2=bold, 4=underline
// biome-ignore lint/suspicious/noBitwiseOperators: shiki bitflag check
const isItalic = (fontStyle: number | undefined) => fontStyle && fontStyle & 1,
  // biome-ignore lint/suspicious/noBitwiseOperators: shiki bitflag check
  isBold = (fontStyle: number | undefined) => fontStyle && fontStyle & 2,
  isUnderline = (fontStyle: number | undefined) =>
    // biome-ignore lint/suspicious/noBitwiseOperators: shiki bitflag check
    fontStyle && fontStyle & 4

interface KeyedLine {
  key: string
  tokens: KeyedToken[]
}
// Transform tokens to include pre-computed keys to avoid noArrayIndexKey lint
interface KeyedToken {
  key: string
  token: ThemedToken
}

const addKeysToTokens = (lines: ThemedToken[][]): KeyedLine[] =>
    lines.map((line, lineIdx) => ({
      key: `line-${lineIdx}`,
      tokens: line.map((token, tokenIdx) => ({
        key: `line-${lineIdx}-${tokenIdx}`,
        token
      }))
    })),
  // Token rendering component
  TokenSpan = ({ token }: { token: ThemedToken }) => (
    <span
      className='dark:bg-(--shiki-dark-bg)! dark:text-(--shiki-dark)!'
      style={
        {
          backgroundColor: token.bgColor,
          color: token.color,
          ...token.htmlStyle,
          fontStyle: isItalic(token.fontStyle) ? 'italic' : undefined,
          fontWeight: isBold(token.fontStyle) ? 'bold' : undefined,
          textDecoration: isUnderline(token.fontStyle) ? 'underline' : undefined
        } as CSSProperties
      }>
      {token.content}
    </span>
  ),
  LINE_NUMBER_CLASSES = cn(
    'block',
    'before:content-[counter(line)]',
    'before:inline-block',
    'before:[counter-increment:line]',
    'before:w-8',
    'before:mr-4',
    'before:text-right',
    'before:text-muted-foreground/50',
    'before:font-mono',
    'before:select-none'
  ),
  // Line rendering component
  LineSpan = ({ keyedLine, showLineNumbers }: { keyedLine: KeyedLine; showLineNumbers: boolean }) => (
    <span className={showLineNumbers ? LINE_NUMBER_CLASSES : 'block'}>
      {keyedLine.tokens.length === 0
        ? '\n'
        : keyedLine.tokens.map(({ key, token }) => <TokenSpan key={key} token={token} />)}
    </span>
  )

interface CodeBlockContextType {
  code: string
}

// Types
type CodeBlockProps = HTMLAttributes<HTMLDivElement> & {
  code: string
  language: BundledLanguage
  showLineNumbers?: boolean
}

interface TokenizedCode {
  bg: string
  fg: string
  tokens: ThemedToken[][]
}

const CodeBlockContext = createContext<CodeBlockContextType>({
    code: ''
  }),
  // Highlighter cache (singleton per language)
  highlighterCache = new Map<string, Promise<HighlighterGeneric<BundledLanguage, BundledTheme>>>(),
  // Token cache
  tokensCache = new Map<string, TokenizedCode>(),
  // Subscribers for async token updates
  subscribers = new Map<string, Set<(result: TokenizedCode) => void>>(),
  getTokensCacheKey = (code: string, language: BundledLanguage) => {
    const start = code.slice(0, 100),
      end = code.length > 100 ? code.slice(-100) : ''
    return `${language}:${code.length}:${start}:${end}`
  },
  getHighlighter = async (language: BundledLanguage): Promise<HighlighterGeneric<BundledLanguage, BundledTheme>> => {
    const cached = highlighterCache.get(language)
    if (cached) return cached

    const highlighterPromise = createHighlighter({
      langs: [language],
      themes: ['github-light', 'github-dark']
    })

    highlighterCache.set(language, highlighterPromise)
    return highlighterPromise
  },
  // Create raw tokens for immediate display while highlighting loads
  createRawTokens = (code: string): TokenizedCode => ({
    bg: 'transparent',
    fg: 'inherit',
    tokens: code.split('\n').map(line =>
      line === ''
        ? []
        : [
            {
              color: 'inherit',
              content: line
            } as ThemedToken
          ]
    )
  })

// Synchronous highlight with callback for async results
export const highlightCode = (
  code: string,
  language: BundledLanguage,
  callback?: (result: TokenizedCode) => void
): null | TokenizedCode => {
  const tokensCacheKey = getTokensCacheKey(code, language),
    // Return cached result if available
    cached = tokensCache.get(tokensCacheKey)
  if (cached) return cached

  // Subscribe callback if provided
  if (callback) {
    if (!subscribers.has(tokensCacheKey)) subscribers.set(tokensCacheKey, new Set())

    subscribers.get(tokensCacheKey)?.add(callback)
  }

  // Start highlighting in background
  getHighlighter(language)
    .then(highlighter => {
      const availableLangs = highlighter.getLoadedLanguages(),
        langToUse = availableLangs.includes(language) ? language : 'text',
        result = highlighter.codeToTokens(code, {
          lang: langToUse,
          themes: {
            dark: 'github-dark',
            light: 'github-light'
          }
        }),
        tokenized: TokenizedCode = {
          bg: result.bg ?? '',
          fg: result.fg ?? '',
          tokens: result.tokens
        }

      // Cache the result
      tokensCache.set(tokensCacheKey, tokenized)

      // Notify all subscribers
      const subs = subscribers.get(tokensCacheKey)
      if (subs) {
        for (const sub of subs) sub(tokenized)

        subscribers.delete(tokensCacheKey)
      }
    })
    .catch((error: unknown) => {
      console.error('Failed to highlight code:', error)
      subscribers.delete(tokensCacheKey)
    })

  return null
}

// eslint-disable-next-line react/display-name
const CodeBlockBody = memo(
  ({
    className,
    showLineNumbers,
    tokenized
  }: {
    className?: string
    showLineNumbers: boolean
    tokenized: TokenizedCode
  }) => {
    const preStyle = useMemo(
        () => ({
          backgroundColor: tokenized.bg,
          color: tokenized.fg
        }),
        [tokenized.bg, tokenized.fg]
      ),
      keyedLines = useMemo(() => addKeysToTokens(tokenized.tokens), [tokenized.tokens])

    return (
      <pre
        className={cn('m-0 p-4 text-sm dark:bg-(--shiki-dark-bg)! dark:text-(--shiki-dark)!', className)}
        style={preStyle}>
        <code className={cn('font-mono text-sm', showLineNumbers && '[counter-increment:line_0] [counter-reset:line]')}>
          {keyedLines.map(keyedLine => (
            <LineSpan key={keyedLine.key} keyedLine={keyedLine} showLineNumbers={showLineNumbers} />
          ))}
        </code>
      </pre>
    )
  },
  (prevProps, nextProps) =>
    prevProps.tokenized === nextProps.tokenized &&
    prevProps.showLineNumbers === nextProps.showLineNumbers &&
    prevProps.className === nextProps.className
)

export const CodeBlockContainer = ({
  className,
  language,
  style,
  ...props
}: HTMLAttributes<HTMLDivElement> & { language: string }) => (
  <div
    className={cn('group relative w-full overflow-hidden rounded-md border bg-background text-foreground', className)}
    data-language={language}
    style={{
      containIntrinsicSize: 'auto 200px',
      contentVisibility: 'auto',
      ...style
    }}
    {...props}
  />
)

export const CodeBlockHeader = ({ children, className, ...props }: HTMLAttributes<HTMLDivElement>) => (
  <div
    className={cn('flex items-center justify-between bg-muted/80 px-3 py-2 text-xs text-muted-foreground', className)}
    {...props}>
    {children}
  </div>
)

export const CodeBlockTitle = ({ children, className, ...props }: HTMLAttributes<HTMLDivElement>) => (
  <div className={cn('flex items-center gap-2', className)} {...props}>
    {children}
  </div>
)

export const CodeBlockFilename = ({ children, className, ...props }: HTMLAttributes<HTMLSpanElement>) => (
  <span className={cn('font-mono', className)} {...props}>
    {children}
  </span>
)

export const CodeBlockActions = ({ children, className, ...props }: HTMLAttributes<HTMLDivElement>) => (
  <div className={cn('flex items-center gap-2', className)} {...props}>
    {children}
  </div>
)

export const CodeBlockContent = ({
  code,
  language,
  showLineNumbers
}: {
  code: string
  language: BundledLanguage
  showLineNumbers?: boolean
}) => {
  // Memoized raw tokens for immediate display
  const rawTokens = useMemo(() => createRawTokens(code), [code]),
    // Try to get cached result synchronously, otherwise use raw tokens
    [tokenized, setTokenized] = useState<TokenizedCode>(() => highlightCode(code, language) ?? rawTokens)

  useEffect(() => {
    // Reset to raw tokens when code changes (shows current code, not stale tokens)
    setTokenized(highlightCode(code, language) ?? rawTokens)

    // Subscribe to async highlighting result
    highlightCode(code, language, setTokenized)
  }, [code, language, rawTokens])

  return (
    <div className='relative overflow-auto'>
      <CodeBlockBody showLineNumbers={Boolean(showLineNumbers)} tokenized={tokenized} />
    </div>
  )
}

export const CodeBlock = ({ children, className, code, language, showLineNumbers, ...props }: CodeBlockProps) => (
  <CodeBlockContext value={{ code }}>
    <CodeBlockContainer className={className} language={language} {...props}>
      {children}
      <CodeBlockContent code={code} language={language} showLineNumbers={showLineNumbers} />
    </CodeBlockContainer>
  </CodeBlockContext>
)

export type CodeBlockCopyButtonProps = ComponentProps<typeof Button> & {
  onCopy?: () => void
  onError?: (error: Error) => void
  timeout?: number
}

export const CodeBlockCopyButton = ({
  children,
  className,
  onCopy,
  onError,
  timeout = 2000,
  ...props
}: CodeBlockCopyButtonProps) => {
  const [isCopied, setIsCopied] = useState(false),
    timeoutRef = useRef<number>(0),
    { code } = use(CodeBlockContext),
    copyToClipboard = async () => {
      // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
      if (typeof window === 'undefined' || !navigator?.clipboard?.writeText) {
        onError?.(new Error('Clipboard API not available'))
        return
      }

      try {
        if (!isCopied) {
          await navigator.clipboard.writeText(code)
          setIsCopied(true)
          onCopy?.()
          timeoutRef.current = globalThis.setTimeout(() => setIsCopied(false), timeout) as unknown as number
        }
      } catch (error) {
        onError?.(error as Error)
      }
    }

  useEffect(
    () => () => {
      globalThis.clearTimeout(timeoutRef.current)
    },
    []
  )

  const Icon = isCopied ? CheckIcon : CopyIcon

  return (
    // eslint-disable-next-line @typescript-eslint/strict-void-return
    <Button className={cn('shrink-0', className)} onClick={copyToClipboard} size='icon' variant='ghost' {...props}>
      {children ?? <Icon size={14} />}
    </Button>
  )
}

export type CodeBlockLanguageSelectorProps = ComponentProps<typeof Select>

export const CodeBlockLanguageSelector = (props: CodeBlockLanguageSelectorProps) => <Select {...props} />

export type CodeBlockLanguageSelectorTriggerProps = ComponentProps<typeof SelectTrigger>

export const CodeBlockLanguageSelectorTrigger = ({ className, ...props }: CodeBlockLanguageSelectorTriggerProps) => (
  <SelectTrigger
    className={cn('h-7 border-none bg-transparent px-2 text-xs shadow-none', className)}
    size='sm'
    {...props}
  />
)

export type CodeBlockLanguageSelectorValueProps = ComponentProps<typeof SelectValue>

export const CodeBlockLanguageSelectorValue = (props: CodeBlockLanguageSelectorValueProps) => <SelectValue {...props} />

export type CodeBlockLanguageSelectorContentProps = ComponentProps<typeof SelectContent>

export const CodeBlockLanguageSelectorContent = ({ align = 'end', ...props }: CodeBlockLanguageSelectorContentProps) => (
  <SelectContent align={align} {...props} />
)

export type CodeBlockLanguageSelectorItemProps = ComponentProps<typeof SelectItem>

export const CodeBlockLanguageSelectorItem = (props: CodeBlockLanguageSelectorItemProps) => <SelectItem {...props} />

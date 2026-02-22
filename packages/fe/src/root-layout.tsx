import '@a/ui/globals.css'
import type { ReactNode } from 'react'

import { Toaster } from '@a/ui/sonner'
import { ThemeProvider } from 'next-themes'
import { Suspense } from 'react'

import ErrorBoundary from './error-boundary'

interface RootLayoutProps {
  children: ReactNode
  providers?: ReactNode
}

const RootLayout = ({ children, providers }: RootLayoutProps) => (
  <html lang='en' suppressHydrationWarning>
    <body className='min-h-screen bg-background font-sans tracking-tight text-foreground antialiased'>
      <Suspense>
        <ErrorBoundary>
          {providers ?? (
            <ThemeProvider attribute='class' defaultTheme='system' enableSystem>
              {children}
            </ThemeProvider>
          )}
          <Toaster duration={1000} />
        </ErrorBoundary>
      </Suspense>
    </body>
  </html>
)

export default RootLayout

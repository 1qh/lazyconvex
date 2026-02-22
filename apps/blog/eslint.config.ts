import baseConfig from '@a/eslint-config/base'
import nextjsConfig from '@a/eslint-config/nextjs'
import reactConfig from '@a/eslint-config/react'
import restrictEnvAccess from '@a/eslint-config/restrict-env'
import { defineConfig } from 'eslint/config'

export default defineConfig({ ignores: ['.next/**', 'e2e/**'] }, baseConfig, reactConfig, nextjsConfig, restrictEnvAccess)

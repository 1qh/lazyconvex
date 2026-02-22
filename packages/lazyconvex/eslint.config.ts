import baseConfig from '@a/eslint-config/base'
import reactConfig from '@a/eslint-config/react'
import { defineConfig } from 'eslint/config'

export default defineConfig({ ignores: ['dist/**'] }, baseConfig, reactConfig)

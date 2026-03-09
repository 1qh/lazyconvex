import { defineConfig } from 'lintmax'

export default defineConfig({
  biome: {
    ignorePatterns: ['mobile/maestro', 'tooling/eslint', 'apps/*/next-env.d.ts'],
    overrides: [
      {
        disableLinter: true,
        includes: ['packages/ui/**']
      },
      {
        disableLinter: true,
        includes: ['**/generated/**', '**/_generated/**']
      },
      {
        includes: ['**/e2e/**', '**/maestro/**'],
        rules: {
          'performance/noAwaitInLoops': 'off',
          'suspicious/noEmptyBlockStatements': 'off'
        }
      }
    ],
    rules: {
      'nursery/noPlaywrightUselessAwait': 'off',
      'nursery/useAwaitThenable': 'off'
    }
  },
  oxlint: {
    ignorePatterns: ['_generated/', 'mobile/maestro/', 'packages/ui/', 'tooling/eslint'],
    overrides: [
      {
        files: ['**/convex/blogProfile.ts', '**/convex/mobileAi.ts', '**/convex/orgProfile.ts'],
        rules: {
          'unicorn/filename-case': 'off'
        }
      }
    ],
    rules: {
      '@next/next/no-img-element': 'off',
      'eslint/max-depth': 'off',
      'eslint/sort-keys': 'off',
      'eslint/no-await-in-loop': 'off',
      'eslint/no-empty-function': 'off',
      'import/no-unassigned-import': 'off',
      'jsx-a11y/prefer-tag-over-role': 'off',
      'promise/prefer-await-to-callbacks': 'off',
      'promise/prefer-await-to-then': 'off',
      'react-perf/jsx-no-jsx-as-prop': 'off',
      'react-perf/jsx-no-new-array-as-prop': 'off',
      'react-perf/jsx-no-new-object-as-prop': 'off',
      'react/jsx-handler-names': 'off',
      'react/no-danger': 'off',
      'unicorn/no-await-expression-member': 'off',
      'unicorn/no-document-cookie': 'off'
    }
  }
})

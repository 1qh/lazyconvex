import { test as baseTest } from '@playwright/test'

import MoviePage from './pages/movie'

interface Fixtures {
  moviePage: MoviePage
}

const test = baseTest.extend<Fixtures>({
  moviePage: async ({ page }, run) => {
    const moviePage = new MoviePage(page)
    await run(moviePage)
  }
})

export { test }
export { expect } from '@playwright/test'

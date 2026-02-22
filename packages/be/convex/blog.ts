import { crud } from '../lazy'
import { owned } from '../t'

export const {
  bulkRm,
  bulkUpdate,
  create,
  pub: { list, read, search },
  rm,
  update
} = crud('blog', owned.blog, { rateLimit: { max: 10, window: 60_000 }, search: 'content' })

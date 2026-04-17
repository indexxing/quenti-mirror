FROM oven/bun:1-alpine AS base

# ---- dependencies ----
FROM base AS deps
WORKDIR /app
COPY package.json bun.lockb ./
COPY apps/next/package.json apps/next/
COPY packages/auth/package.json packages/auth/
COPY packages/branding/package.json packages/branding/
COPY packages/components/package.json packages/components/
COPY packages/core/package.json packages/core/
COPY packages/cortex/package.json packages/cortex/
COPY packages/drizzle/package.json packages/drizzle/
COPY packages/emails/package.json packages/emails/
COPY packages/enterprise/package.json packages/enterprise/
COPY packages/env/package.json packages/env/
COPY packages/images/package.json packages/images/
COPY packages/inngest/package.json packages/inngest/
COPY packages/interfaces/package.json packages/interfaces/
COPY packages/lib/package.json packages/lib/
COPY packages/payments/package.json packages/payments/
COPY packages/prisma/package.json packages/prisma/
COPY packages/trpc/package.json packages/trpc/
COPY packages/types/package.json packages/types/
RUN bun install --frozen-lockfile

# ---- builder ----
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/next/node_modules ./apps/next/node_modules
COPY . .

ENV SKIP_ENV_VALIDATION=1
ENV DOCKER_BUILD=1
RUN bun run --cwd packages/prisma db:generate 2>/dev/null || true
RUN bun x turbo build --filter=@quenti/next...

# ---- runner ----
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder /app/apps/next/public ./apps/next/public
COPY --from=builder --chown=nextjs:nodejs /app/apps/next/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/next/.next/static ./apps/next/.next/static

COPY --from=builder /app/packages/prisma ./packages/prisma
COPY --from=builder /app/node_modules/.bin/prisma ./node_modules/.bin/prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma
COPY --chown=nextjs:nodejs entrypoint.sh ./entrypoint.sh
RUN chmod +x entrypoint.sh

USER nextjs
EXPOSE 3000

CMD ["/app/entrypoint.sh"]
